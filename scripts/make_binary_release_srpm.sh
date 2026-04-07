#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: make_binary_release_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
release_asset_x86_64="${RELEASE_ASSET_X86_64:-}"
release_asset_aarch64="${RELEASE_ASSET_AARCH64:-}"
doc_files="${DOC_FILES:-LICENSE README.md}"

while [[ $# -gt 0 ]]; do
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

if [[ -z "$spec" || -z "$outdir" || -z "$package_name" || -z "$upstream_url" || -z "$release_asset_x86_64" || -z "$release_asset_aarch64" ]]; then
  usage >&2
  exit 1
fi

spec="$(realpath "$spec")"
mkdir -p "$outdir"
outdir="$(realpath "$outdir")"

version="$(awk '$1 == "Version:" { print $2; exit }' "$spec")"
if [[ -z "$version" ]]; then
  echo "Unable to determine version from $spec" >&2
  exit 1
fi

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
srcdir="${workdir}/${package_name}-${version}-src"
docsdir="${workdir}/${package_name}-${version}-docs"
repo_path="${upstream_url#https://github.com/}"
repo_path="${repo_path%.git}"
mkdir -p "$sources_dir" "$docsdir"

download_release_asset() {
  local asset_name="$1"
  local output_name="$2"
  curl -fsSL "https://github.com/${repo_path}/releases/download/${tag}/${asset_name}" \
    -o "${sources_dir}/${output_name}"
}

download_release_asset "${release_asset_x86_64}" "${package_name}-${version}-x86_64.tar.gz"
download_release_asset "${release_asset_aarch64}" "${package_name}-${version}-aarch64.tar.gz"

git clone --depth 1 --branch "${tag}" "${upstream_url}" "${srcdir}"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
