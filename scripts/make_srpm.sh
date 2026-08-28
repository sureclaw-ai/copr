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

# Rewrite the first `go X.Y[.Z]` directive in a go.mod to a given version.
rewrite_go_directive() {
  _gm="$1"
  _ver="$2"
  _tmp="${_gm}.tmp"
  awk -v compat="$_ver" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$_gm" >"$_tmp" || {
    rm -f "$_tmp"
    return 1
  }
  mv "$_tmp" "$_gm"
}

# Remove `tool` directives (both single-line and block form) from a go.mod.
# Tool dependencies are dev-time code generators (e.g. sqlc) that are never
# compiled into the packaged binary, but their own go.mod requirements can drag
# the whole module's minimum Go version above what some target chroots ship,
# defeating GO_VERSION_COMPAT. Dropping the tool directive lets the compat
# version take effect; a subsequent `go mod tidy` prunes the now-unreferenced
# requires.
strip_go_tool_directives() {
  _gm="$1"
  _tmp="${_gm}.tmp"
  awk '
    BEGIN { intool = 0 }
    /^tool \(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool / { next }
    { print }
  ' "$_gm" >"$_tmp" || {
    rm -f "$_tmp"
    return 1
  }
  mv "$_tmp" "$_gm"
}

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  strip_go_tool_directives "${srcdir}/go.mod" || {
    echo "Unable to strip tool directives from ${srcdir}/go.mod" >&2
    exit 1
  }
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat" || {
    echo "Unable to update go directive in ${srcdir}/go.mod" >&2
    exit 1
  }
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

# `go mod tidy` can raise the go directive back up while resolving the module
# graph (a pruned tool dependency is still visited before it is dropped). Re-pin
# to the requested compat version and tidy once more so the module graph is
# consistent at the lower version before it is captured in the source tarball
# and vendored.
if [ -n "$go_version_compat" ]; then
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat" || {
    echo "Unable to re-pin go directive in ${srcdir}/go.mod" >&2
    exit 1
  }
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    go mod tidy
  )
fi

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod vendor
)

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
