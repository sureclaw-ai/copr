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

require_go_mod() {
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "Expected ${srcdir}/go.mod to exist" >&2
    exit 1
  fi
}

# Rewrite the go.mod "go" directive to $go_version_compat (no-op if unset).
# Called twice: once before "go mod tidy" so the tidy/vendor steps can run
# under a Go toolchain older than upstream requests, and once after vendoring
# because "go mod tidy" may re-raise the directive to satisfy a dependency.
apply_go_compat() {
  [ -n "$go_version_compat" ] || return 0
  require_go_mod
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
}

# Drop Go "tool" directives (single-line and block forms). These name dev-time
# code generators (e.g. sqlc) that aren't needed to compile the package but
# pull their own module graphs into go.mod -- graphs that may require a newer
# Go toolchain than the build chroots ship, breaking vendoring and the build.
strip_go_tool_directives() {
  [ -n "$go_strip_tool_directives" ] || return 0
  require_go_mod
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool \(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool[ \t]/ { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp"
  mv "$go_mod_tmp" "${srcdir}/go.mod"
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

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

strip_go_tool_directives
apply_go_compat

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

# "go mod tidy" may have re-raised the go directive; now that the vendor tree is
# complete, lower it again so the offline "-mod=vendor" build in older chroots
# passes the go-version gate. Editing only the "go" line keeps go.mod consistent
# with vendor/modules.txt.
apply_go_compat

# Source tarball excludes the freshly vendored tree (shipped separately as
# Source1) so the two archives don't overlap.
tar -C "$workdir" --exclude "${package_name}-${version}/vendor" \
  -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
