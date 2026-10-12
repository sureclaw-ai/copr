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
go_drop_tools="${GO_DROP_TOOLS:-}"

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

# Drop dev-only Go tool dependencies (e.g. codegen tools declared via a
# `tool` directive in go.mod). They are never compiled to build the released
# binary, but `go mod tidy` pulls their module graph in and, because such a
# tool can require a newer Go than the target distributions ship, raises the
# module's `go` directive above what the build chroots provide. Dropping them
# keeps the vendored tree buildable on older toolchains and much smaller.
if [ -n "$go_drop_tools" ]; then
  for tool in $go_drop_tools; do
    (
      cd "$srcdir"
      export GOFLAGS="-mod=mod"
      export GOWORK=off
      go mod edit -droptool="$tool"
    )
  done
fi

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to update go directive in ${srcdir}/go.mod" >&2
    exit 1
  }
  mv "$go_mod_tmp" "${srcdir}/go.mod"
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

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod vendor
)

# `go mod tidy` may raise the `go` directive above $go_version_compat based on
# the dependency graph, clobbering the pre-tidy rewrite above. Re-apply the
# compat version now that vendoring is done, so the go.mod shipped in the
# source tarball builds on toolchains as old as $go_version_compat. The
# already-vendored tree stays consistent for `go build -mod=vendor`.
if [ -n "$go_version_compat" ]; then
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    go mod edit -go="$go_version_compat"
  )
fi

# Exclude the freshly vendored tree from the source tarball; it ships
# separately as the vendor tarball below.
tar -C "$workdir" \
  --exclude="${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
