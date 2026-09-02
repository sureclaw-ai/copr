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

if [ -n "$go_strip_tool_directives" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_STRIP_TOOL_DIRECTIVES was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  # Drop `tool` directives (Go 1.24+ dev-only codegen/lint helpers). They are
  # never needed to build the release binary, but `go mod tidy`/`vendor` pull
  # their dependency trees into the vendored SRPM and can force a newer Go
  # toolchain than the binary itself requires. Handles both the single-line
  # (`tool path`) and block (`tool ( ... )`) forms.
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool \(/ { inblock = 1; next }
    inblock && /^\)/ { inblock = 0; next }
    inblock { next }
    /^tool[ \t]/ { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to strip tool directives from ${srcdir}/go.mod" >&2
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
  go mod vendor
)

# Pin the go.mod language directive last, AFTER `go mod tidy`/`go mod vendor`
# (which raise the directive to satisfy the module graph and require a
# consistent go.mod). This keeps the shipped SRPM buildable on the older Go
# toolchains present in some build chroots, even when a transitive dependency
# declares a newer `go` directive than the binary itself needs. It runs after
# vendoring so it does not trip go's module-consistency check; the vendored
# `-mod=vendor` build only enforces the main module's `go` directive.
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

tar -C "$workdir" --exclude="${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
