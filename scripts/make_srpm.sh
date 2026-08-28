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

# Pin the go.mod `go` directive to $go_version_compat. Called both before and
# after `go mod tidy`: `tidy` transiently raises the directive to satisfy a
# dependency's higher `go` requirement (and never lowers it back), so a second
# pass after tidy is needed to leave the shipped go.mod at the compat version.
apply_go_compat() {
  phase="$1"
  [ -n "$go_version_compat" ] || return 0
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
    echo "Unable to update go directive in ${srcdir}/go.mod (${phase})" >&2
    exit 1
  }
  mv "$go_mod_tmp" "${srcdir}/go.mod"
}

apply_go_compat before-tidy

# Drop any Go `tool` directives (Go 1.24+ tool dependencies). These reference
# codegen/dev tools such as sqlc that are never needed to build the packaged
# binary from committed sources, yet their own `go` requirements can raise the
# module's go floor above what target chroots provide (breaking offline builds
# with "go.mod requires go >= X") and pull heavy, sometimes unbuildable
# dependencies into the vendor tree. Removing them lets `go mod tidy` prune the
# now-unused requires so the module settles on the intended go version.
if [ -f "${srcdir}/go.mod" ]; then
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool[ \t]*\(/ { in_tool = 1; next }
    in_tool && /^[ \t]*\)/ { in_tool = 0; next }
    in_tool { next }
    /^tool[ \t]+[^ \t(]/ { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" && mv "$go_mod_tmp" "${srcdir}/go.mod" || {
    rm -f "$go_mod_tmp"
    echo "Unable to strip tool directives from ${srcdir}/go.mod" >&2
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
  # Allow the toolchain needed to load the module graph to be fetched. After
  # stripping tool directives, `go mod tidy` must briefly load the (now unused)
  # tool dependencies before pruning them; some distro Go packages default to
  # GOTOOLCHAIN=local, which would fail that load when a dependency declares a
  # newer go than the builder ships. The SRPM stage has network access.
  export GOTOOLCHAIN=auto
  go mod tidy
)

# Re-pin the go directive: `go mod tidy` above may have raised it to satisfy a
# dependency it then pruned, leaving an inflated floor. This runs before the
# source tarball is created so the shipped go.mod carries the compat version.
apply_go_compat after-tidy

# Re-run tidy so the lowered go directive and the pruned require set are mutually
# consistent again. The first tidy already removed the pruned tool dependencies
# from the require list, so this pass finds nothing that needs a newer go and
# leaves the directive at the compat version. Without it `go mod vendor` (and the
# in-chroot build) would reject the hand-edited go.mod as needing another tidy.
if [ -n "$go_version_compat" ]; then
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    export GOTOOLCHAIN=auto
    go mod tidy
  )
fi

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  export GOTOOLCHAIN=auto
  go mod vendor
)

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
