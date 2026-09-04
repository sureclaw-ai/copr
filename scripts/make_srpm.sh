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

# Pin the go directive down to a version that every target chroot ships.
#
# This must run BOTH before and after `go mod tidy`: some upstreams pull in a
# build-time `tool` dependency (e.g. sqlc) that declares a newer `go` directive,
# and `go mod tidy` raises the main module's `go` line to match. Rewriting only
# once (before tidy) is silently undone, so the shipped go.mod ends up requiring
# a toolchain the older chroots (and sometimes the SRPM builder) don't have,
# which is exactly what breaks the build. Re-applying after tidy guarantees the
# go.mod that lands in the source tarball is the compat version.
rewrite_go_compat() {
  if [ -z "$go_version_compat" ]; then
    return 0
  fi
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  # Rewrite the `go` directive to the compat version and drop any `toolchain`
  # line so the chroot build does not try to fetch a newer toolchain offline.
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    /^toolchain / { next }
    { print }
    END { if (!updated) exit 2 }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to update go directive in ${srcdir}/go.mod" >&2
    exit 1
  }
  mv "$go_mod_tmp" "${srcdir}/go.mod"
}

# Drop `tool` directives from go.mod. Tool dependencies are build-time code
# generators (e.g. sqlc) that the RPM build never runs, but they can declare a
# much newer `go` directive that drags the whole module's required go version up
# past what the target chroots ship. Removing them lets `go mod tidy` prune the
# tool-only dependency subtree so the module builds on the compat toolchain.
# Only done when GO_VERSION_COMPAT is set (the opt-in "build on older go" path).
strip_go_tools() {
  if [ -z "$go_version_compat" ]; then
    return 0
  fi
  if [ ! -f "${srcdir}/go.mod" ]; then
    return 0
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool \(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool / { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp"
  mv "$go_mod_tmp" "${srcdir}/go.mod"
}

strip_go_tools
rewrite_go_compat

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  # Allow fetching the toolchain a dependency's go directive may require; the
  # shipped go.mod is pinned back down to the compat version immediately after.
  export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
  go mod tidy
)

if [ -n "$go_version_compat" ]; then
  # Pruning the tool dependencies above can transiently raise the `go` directive
  # while `go mod tidy` reconciles the graph. Pin it back down and tidy once more
  # so go.mod/go.sum are self-consistent at the compat version before vendoring.
  rewrite_go_compat
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
    go mod tidy
  )
fi

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
  go mod vendor
)

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
