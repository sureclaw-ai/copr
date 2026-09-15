#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Builds an SRPM for a project that ships prebuilt per-architecture binaries as
scoped npm packages (one package per platform/arch). Downloads the x86_64 and
aarch64 npm tarballs and packages them alongside a docs tarball cloned from the
upstream git tag.

Environment variables:
  PACKAGE_NAME         Required. RPM package name (used for source filenames).
  NPM_PACKAGE_X86_64   Required. npm package for x86_64, e.g.
                       "@opencode/cli-linux-x64-baseline".
  NPM_PACKAGE_AARCH64  Required. npm package for aarch64, e.g.
                       "@opencode/cli-linux-arm64".
  UPSTREAM_URL         Required. git URL cloned to collect DOC_FILES.
  UPSTREAM_TAG_PREFIX  Optional. Tag prefix, default "v".
  DOC_FILES            Optional. Space-separated docs to bundle,
                       default "LICENSE README.md".
  NPM_REGISTRY         Optional. Registry base, default
                       "https://registry.npmjs.org".
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
doc_files="${DOC_FILES:-LICENSE README.md}"
npm_registry="${NPM_REGISTRY:-https://registry.npmjs.org}"

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

if [ -z "$spec" ] || [ -z "$outdir" ] || [ -z "$package_name" ] || \
   [ -z "$npm_package_x86_64" ] || [ -z "$npm_package_aarch64" ] || \
   [ -z "$upstream_url" ]; then
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
sources_dir="${workdir}/sources"
docsdir="${workdir}/${package_name}-${version}-docs"
mkdir -p "$sources_dir" "$docsdir"

curl_download() {
  url="$1"
  output_path="$2"
  max_attempts=5
  attempt=1
  delay_seconds=2

  while [ "$attempt" -le "$max_attempts" ]; do
    rm -f "$output_path"
    if curl -fsSL "$url" -o "$output_path"; then
      return 0
    fi

    if [ "$attempt" -eq "$max_attempts" ]; then
      echo "Failed to download ${url} after ${max_attempts} attempts" >&2
      return 1
    fi

    sleep "$delay_seconds"
    attempt=$((attempt + 1))
  done
}

# npm serves a package's tarball at
# <registry>/<package>/-/<unscoped-name>-<version>.tgz. This mirrors the URL
# scheme used by the project's own install script, so no metadata lookup (and
# thus no python/jq dependency) is needed.
download_npm_package() {
  npm_package="$1"
  output_name="$2"
  unscoped="${npm_package##*/}"
  url="${npm_registry}/${npm_package}/-/${unscoped}-${version}.tgz"
  curl_download "$url" "${sources_dir}/${output_name}"
}

download_npm_package "$npm_package_x86_64" "${package_name}-${version}-x86_64.tar.gz"
download_npm_package "$npm_package_aarch64" "${package_name}-${version}-aarch64.tar.gz"

git clone --depth 1 --branch "$tag" "$upstream_url" "${workdir}/src"
for doc_file in ${doc_files}; do
  cp "${workdir}/src/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
