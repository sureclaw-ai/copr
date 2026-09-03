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

# Rewrite the `go` directive in a go.mod to $go_version_compat. `go mod tidy`
# can raise the directive back up to whatever the dependency graph requires, so
# this is applied both before tidy (so tidy can run under the builder's Go) and
# again afterwards (so the shipped go.mod targets the compat version).
rewrite_go_directive() {
  go_mod="$1"
  go_mod_tmp="${go_mod}.tmp"
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$go_mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to update go directive in ${go_mod}" >&2
    exit 1
  }
  mv "$go_mod_tmp" "$go_mod"
}

# Drop Go `tool` directives (both the single-line and block forms). Tool
# dependencies are only needed for code generation, never to build the package
# binary, and they can pull modules that require a newer Go toolchain than the
# target build roots ship. `go mod tidy` prunes the now-unused requires.
if [ -n "$go_strip_tool_directives" ] && [ -f "${srcdir}/go.mod" ]; then
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool[ \t]*\(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool[ \t]+[^ \t(]/ { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp"
  mv "$go_mod_tmp" "${srcdir}/go.mod"
fi

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  rewrite_go_directive "${srcdir}/go.mod"
fi

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod tidy
  go mod vendor
)

# `go mod tidy` may have raised the `go` directive to satisfy the dependency
# graph. Pin it back down to the compat version now that tidy/vendor are done,
# so the shipped go.mod (and the `-mod=vendor` build in mock) targets a Go
# toolchain the build roots actually ship. This must happen after `go mod
# vendor`, which refuses to run against a go.mod whose directive is out of sync
# with the resolved module graph.
if [ -n "$go_version_compat" ]; then
  rewrite_go_directive "${srcdir}/go.mod"
fi

# Vendor tree ships as a separate source; keep it out of the main source
# tarball (the spec unpacks it via `%autosetup -a1`).
tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor
tar -C "$workdir" --exclude="${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
