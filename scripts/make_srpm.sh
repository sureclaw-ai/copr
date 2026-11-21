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

# Pin the go.mod "go" directive down to $go_version_compat and drop any
# "toolchain" line. COPR's per-chroot builds run under GOTOOLCHAIN=local, so Go
# never downloads a newer toolchain and enforces only the "go" directive: if a
# chroot's bundled Go is older than that directive, `go build` aborts before
# compiling. Lowering the directive to a version every target chroot satisfies
# keeps the build working even on distros whose Go lags (e.g. opensuse-leap).
rewrite_go_mod_compat() {
  go_mod_path="$1"
  if [ ! -f "$go_mod_path" ]; then
    echo "GO_VERSION_COMPAT was set but ${go_mod_path} does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${go_mod_path}.tmp"
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    /^toolchain / { next }
    { print }
    END { if (!updated) exit 2 }
  ' "$go_mod_path" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to update go directive in ${go_mod_path}" >&2
    exit 1
  }
  mv "$go_mod_tmp" "$go_mod_path"
}

# Apply once before `go mod tidy` so tidy can run even when upstream's directive
# is newer than the builder's Go.
if [ -n "$go_version_compat" ]; then
  rewrite_go_mod_compat "${srcdir}/go.mod"
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

# `go mod tidy`/`go mod vendor` re-raise the "go" directive to satisfy
# dependencies (and may re-add a toolchain line), undoing the pre-tidy rewrite.
# Re-apply it now, after vendoring is complete, so the lowered directive is what
# actually ships. Done after `go mod vendor` (not before) because vendoring
# rejects a go.mod whose directive is lower than the module graph requires; the
# subsequent `go build -mod=vendor` in the spec consumes the vendored tree and
# is happy with the lowered directive.
if [ -n "$go_version_compat" ]; then
  rewrite_go_mod_compat "${srcdir}/go.mod"
fi

# Source tarball excludes the vendored tree, which ships separately as the
# vendor tarball and is unpacked over the sources at build time.
tar -C "$workdir" --exclude="${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
