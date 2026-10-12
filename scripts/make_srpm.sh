#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-gogcli}"
upstream_url="${UPSTREAM_URL:-https://github.com/openclaw/gogcli.git}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
go_version_compat="${GO_VERSION_COMPAT:-}"
# Opt-in: when non-empty, re-apply GO_VERSION_COMPAT to go.mod *after* `go mod
# tidy`/`go mod vendor` so it survives tidy bumping the directive up to the
# module graph's floor. Needed when a build-only dependency (e.g. a `tool`
# directive tree) forces a higher `go` directive than the target chroots ship.
go_version_compat_enforce="${GO_VERSION_COMPAT_ENFORCE:-}"
# Opt-in: when non-empty, strip `tool` directives from go.mod before tidy/vendor.
# `tool` directives (Go 1.24+) are build-time helpers (codegen, linters) that are
# never compiled into the packaged binary but drag their whole dependency tree
# into the module graph and vendor set, and can raise the required `go` version.
go_drop_tool_directives="${GO_DROP_TOOL_DIRECTIVES:-}"

# Rewrite the first `go X.Y[.Z]` directive in a go.mod to $2, and drop any
# `toolchain` line (which would otherwise force a specific/newer toolchain).
rewrite_go_directive() {
  _gomod="$1"
  _compat="$2"
  _tmp="${_gomod}.tmp"
  awk -v compat="$_compat" '
    /^toolchain / { next }
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$_gomod" >"$_tmp" || {
    rm -f "$_tmp"
    echo "Unable to update go directive in ${_gomod}" >&2
    exit 1
  }
  mv "$_tmp" "$_gomod"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec)
      spec="$2"
      shift 2
      ;;
    --outdir)
      outdir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$spec" ] || [ -z "$outdir" ]; then
  usage >&2
  exit 1
fi

spec="$(realpath "$spec")"
mkdir -p "$outdir"
outdir="$(realpath "$outdir")"

version="$(awk '$1 == "Version:" { print $2; exit }' "$spec")"
if [ -z "$version" ]; then
  echo "Unable to determine version from $spec" >&2
  exit 1
fi

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

srcdir="${workdir}/${package_name}-${version}"
sources_dir="${workdir}/sources"
mkdir -p "$sources_dir"

git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
commit="$(git -C "$srcdir" rev-parse --short=12 HEAD)"
date="$(TZ=UTC git -C "$srcdir" log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd HEAD)"

if [ -n "$go_drop_tool_directives" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_DROP_TOOL_DIRECTIVES was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool[ \t]*\(/ { intool = 1; next }
    intool && /^\)/  { intool = 0; next }
    intool           { next }
    /^tool[ \t]/     { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp"
  mv "$go_mod_tmp" "${srcdir}/go.mod"
fi

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  # Rewrite before tidy so `go mod tidy` can even start when the upstream `go`
  # directive is newer than the builder's toolchain (GOTOOLCHAIN=local).
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat"
fi

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod tidy
)

if [ -n "$go_version_compat_enforce" ]; then
  if [ -z "$go_version_compat" ]; then
    echo "GO_VERSION_COMPAT_ENFORCE requires GO_VERSION_COMPAT to be set" >&2
    exit 1
  fi
  # `go mod vendor` refuses to run against a downgraded directive, so vendor at
  # the directive tidy settled on, then pin the shipped go.mod back down. The
  # vendored (imported) modules already support the compat version, so the built
  # binary compiles on any chroot whose toolchain satisfies it.
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    go mod vendor
  )
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat"

  # Source tarball must be built after the final pin and must exclude vendor/
  # (shipped separately as Source1).
  tar -C "$workdir" \
    --exclude="${package_name}-${version}/vendor" \
    -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"
  tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor
else
  tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    go mod vendor
  )

  tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor
fi

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
