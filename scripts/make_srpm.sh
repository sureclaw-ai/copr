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
go_strip_tool_directives="${GO_STRIP_TOOL_DIRECTIVES:-}"

# Rewrite the top-level `go` directive in a go.mod to the compat version.
# `go mod tidy` may raise this directive to satisfy a dependency's requirement,
# so callers rewrite both before and after tidy; the post-tidy rewrite is the
# authoritative one that ends up in the shipped source tarball.
apply_go_compat() {
  gomod="$1"
  compat="$2"
  if [ ! -f "$gomod" ]; then
    echo "GO_VERSION_COMPAT was set but ${gomod} does not exist" >&2
    exit 1
  fi
  tmp="${gomod}.tmp"
  awk -v compat="$compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$gomod" >"$tmp" || {
    rm -f "$tmp"
    echo "Unable to update go directive in ${gomod}" >&2
    exit 1
  }
  mv "$tmp" "$gomod"
}

# Remove `tool` directives (Go 1.24+) from a go.mod. Tool directives pull
# dev-only commands (e.g. code generators) into the module graph, bloating the
# vendor tree and, worse, forcing the module's minimum go version up to whatever
# those tools require. The packaged binary never links them, so drop them before
# `go mod tidy` prunes the now-unused dependencies.
strip_go_tool_directives() {
  gomod="$1"
  if [ ! -f "$gomod" ]; then
    echo "GO_STRIP_TOOL_DIRECTIVES was set but ${gomod} does not exist" >&2
    exit 1
  fi
  tmp="${gomod}.tmp"
  awk '
    /^tool[ \t]*\(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool[ \t]+[^ ]/ { next }
    { print }
  ' "$gomod" >"$tmp"
  mv "$tmp" "$gomod"
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

if [ -n "$go_strip_tool_directives" ]; then
  strip_go_tool_directives "${srcdir}/go.mod"
fi

if [ -n "$go_version_compat" ]; then
  apply_go_compat "${srcdir}/go.mod" "$go_version_compat"
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

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

# `go mod tidy` may have raised the go directive to satisfy a dependency's
# requirement. Re-apply the compat version now that vendoring is complete, so
# the go.mod captured in the source tarball matches the toolchain available in
# older chroots. This is a pure text edit: vendor/ was generated from the
# consistent tidy'd module graph, and `-mod=vendor` validates the require list
# (unchanged), not the go directive.
if [ -n "$go_version_compat" ]; then
  apply_go_compat "${srcdir}/go.mod" "$go_version_compat"
fi

# vendor/ is shipped as a separate source; exclude it from the source tarball to
# avoid duplicating it when %autosetup unpacks both.
tar -C "$workdir" --exclude="${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
