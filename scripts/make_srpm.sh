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

# Rewrite the `go` directive in a go.mod to the compatibility version. `go mod
# tidy` re-raises the directive to the highest version required by anything in
# the module graph (including test-only and tooling dependencies that the
# release binary never compiles), so this is applied again after vendoring.
pin_go_directive() {
  pin_file="$1"
  pin_tmp="${pin_file}.tmp"
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$pin_file" >"$pin_tmp" || {
    rm -f "$pin_tmp"
    echo "Unable to update go directive in ${pin_file}" >&2
    exit 1
  }
  mv "$pin_tmp" "$pin_file"
}

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  # Drop `tool` directives (Go 1.24+ dev tooling used for code generation). The
  # release build only compiles the package binaries, so these tools and their
  # transitive dependencies are never needed, and they can pull in modules that
  # demand a newer `go` than the compatibility version we build against.
  tool_tmp="${srcdir}/go.mod.tmp"
  awk '
    /^tool \(/ { intool = 1; next }
    intool && /^\)/ { intool = 0; next }
    intool { next }
    /^tool[ \t]/ { next }
    { print }
  ' "${srcdir}/go.mod" >"$tool_tmp"
  mv "$tool_tmp" "${srcdir}/go.mod"
  pin_go_directive "${srcdir}/go.mod"
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

if [ -n "$go_version_compat" ]; then
  # `go mod tidy`/`vendor` above may have re-raised the directive; pin it back
  # down so the vendored source builds under the compatibility toolchain.
  pin_go_directive "${srcdir}/go.mod"
fi

tar -C "$workdir" --exclude="${package_name}-${version}/vendor" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
