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
go_drop_tools="${GO_DROP_TOOLS:-}"

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

if [ -n "$go_drop_tools" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_DROP_TOOLS was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  # Remove build-time-only Go tool dependencies (go >= 1.24 `tool` directives).
  # Such tools are only used for code generation and are never needed to build
  # the packaged binary, but they pull the tool's own module graph -- including
  # its (often newer) `go` directive -- into the build. That can require a newer
  # Go toolchain than the SRPM builder or the target chroots provide and break
  # the build for everyone. Both the `tool` directive and the module's
  # `require` line are dropped so `go mod tidy` never needs to load the tool's
  # go.mod (which is what would fail on an older toolchain). Editing is done
  # with `go mod edit`, which only rewrites go.mod and performs no version
  # checks of its own.
  for mod in $go_drop_tools; do
    tools="$(awk '
      /^tool[ \t]*\(/ { inblock = 1; next }
      inblock && /^[ \t]*\)/ { inblock = 0; next }
      inblock { print $1; next }
      /^tool[ \t]+[^ \t(]/ { print $2 }
    ' "${srcdir}/go.mod")"
    for tool in $tools; do
      case "$tool" in
        "$mod" | "$mod"/*)
          (cd "$srcdir" && go mod edit -droptool="$tool")
          ;;
      esac
    done
    (cd "$srcdir" && go mod edit -droprequire="$mod") 2>/dev/null || true
  done
fi

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

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod tidy
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
