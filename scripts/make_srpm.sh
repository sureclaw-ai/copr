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

# Rewrite the main module's `go` directive to $2 (and drop any `toolchain`
# directive). Used to keep the shipped go.mod buildable on chroots whose Go
# toolchain is older than upstream's declared minimum.
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
    echo "Unable to update go directive in $_gomod" >&2
    return 1
  }
  mv "$_tmp" "$_gomod"
}

# Remove `tool` directives (both the single-line and the block form) from a
# go.mod. Tool dependencies are build-time-only code generators whose generated
# output is already committed upstream; they are not needed to compile the
# package, but `go mod tidy`/`go mod vendor` still resolve them and can drag in
# a newer-than-available Go requirement (and a large dependency tree).
strip_go_tool_directives() {
  _gomod="$1"
  _tmp="${_gomod}.tmp"
  awk '
    $1 == "tool" && $2 == "(" { inblk = 1; next }
    inblk && $1 == ")" { inblk = 0; next }
    inblk { next }
    $1 == "tool" { next }
    { print }
  ' "$_gomod" >"$_tmp"
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

if [ -n "$go_strip_tool_directives" ] || [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_STRIP_TOOL_DIRECTIVES/GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
fi

# Strip tool directives before `go mod tidy` so the excised tool (and its
# transitive dependencies) are pruned from go.mod/go.sum and the vendor tree.
if [ -n "$go_strip_tool_directives" ]; then
  strip_go_tool_directives "${srcdir}/go.mod"
fi

# Lower the go directive before `go mod tidy` so tidy/vendor can run even when
# upstream declares a minimum newer than the SRPM builder's toolchain.
if [ -n "$go_version_compat" ]; then
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat" || exit 1
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

# `go mod tidy` may raise the go directive back up (a dependency loaded while
# building the module graph can require a newer toolchain than the target
# chroots ship). Re-apply the compat version to the go.mod that ships in the
# *source* tarball, but keep the tidy-state go.mod for `go mod vendor`, which
# refuses a hand-edited go.mod ("updates to go.mod needed").
go_mod_backup=""
if [ -n "$go_version_compat" ]; then
  go_mod_backup="${workdir}/go.mod.vendorstate"
  cp "${srcdir}/go.mod" "$go_mod_backup"
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat" || exit 1
fi

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

if [ -n "$go_mod_backup" ]; then
  mv "$go_mod_backup" "${srcdir}/go.mod"
fi

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
