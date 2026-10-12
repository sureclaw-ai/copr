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
go_drop_tool_directives="${GO_DROP_TOOL_DIRECTIVES:-}"

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

if [ -n "$go_version_compat" ] || [ "$go_drop_tool_directives" = "1" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT/GO_DROP_TOOL_DIRECTIVES set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
fi

# Drop build-time `tool` directives before touching the module graph. These name
# code-generation tools (e.g. sqlc) whose output is already committed upstream
# and which are never compiled into the packaged binary. Left in place, their
# own module requirements can pin `go mod tidy` to a newer Go than the oldest
# target chroots ship, defeating GO_VERSION_COMPAT below. Handles both the
# single-line (`tool <path>`) and block (`tool ( ... )`) forms.
if [ "$go_drop_tool_directives" = "1" ]; then
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk '
    $1 == "tool" && $2 == "(" { in_block = 1; next }
    in_block && $1 == ")" { in_block = 0; next }
    in_block { next }
    $1 == "tool" { next }
    { print }
  ' "${srcdir}/go.mod" >"$go_mod_tmp"
  mv "$go_mod_tmp" "${srcdir}/go.mod"
fi

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  # First tidy resolves and prunes the module graph (fetching a newer toolchain
  # if the upstream `go` directive demands it, and dropping deps left unused
  # once tool directives were removed).
  go mod tidy
  if [ -n "$go_version_compat" ]; then
    # Lower the `go` directive to the compat baseline and remove any `toolchain`
    # line, then re-tidy so the graph is self-consistent at that version. This
    # must happen AFTER the first tidy: applying it earlier lets tidy ratchet the
    # directive back up to whatever the upstream (or a now-removed tool dep)
    # required. With the offending deps already pruned, the reconcile keeps the
    # directive at the baseline so the offline chroot build (GOTOOLCHAIN=local)
    # accepts it.
    go mod edit -go="$go_version_compat" -toolchain=none
    go mod tidy
  fi
)

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
