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

source_filename_for_asset() {
  local arch="$1"
  local asset_name="$2"
  local suffix=""
  if [[ "$asset_name" == *.* ]]; then
    suffix=".${asset_name#*.}"
  fi
  printf '%s-%s-%s%s' "$package_name" "$version" "$arch" "$suffix"
}

release_source_x86_64="${RELEASE_SOURCE_X86_64:-$(source_filename_for_asset x86_64 "$release_asset_x86_64")}"
release_source_aarch64="${RELEASE_SOURCE_AARCH64:-$(source_filename_for_asset aarch64 "$release_asset_aarch64")}"
docs_source="${DOCS_SOURCE:-${package_name}-${version}-docs.tar.gz}"

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
srcdir="${workdir}/${package_name}-${version}-src"
docsdir="${workdir}/${package_name}-${version}-docs"
repo_path="${upstream_url#https://github.com/}"
repo_path="${repo_path%.git}"
mkdir -p "$sources_dir" "$docsdir"

curl_download() {
  local url="$1"
  local output_path="$2"
  local max_attempts=5
  local attempt=1
  local delay_seconds=2

  while (( attempt <= max_attempts )); do
    rm -f "$output_path"
    if curl -fsSL "$url" -o "$output_path"; then
      return 0
    fi

    if (( attempt == max_attempts )); then
      echo "Failed to download ${url} after ${max_attempts} attempts" >&2
      return 1
    fi

    sleep "$delay_seconds"
    (( attempt += 1 ))
  done
}

download_release_asset() {
  local asset_name="$1"
  local output_name="$2"
  local output_path="${sources_dir}/${output_name}"
  local direct_url="https://github.com/${repo_path}/releases/download/${tag}/${asset_name}"
  curl_download "${direct_url}" "${output_path}"
}

download_release_asset "${release_asset_x86_64}" "${release_source_x86_64}"
download_release_asset "${release_asset_aarch64}" "${release_source_aarch64}"

git clone --depth 1 --branch "${tag}" "${upstream_url}" "${srcdir}"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${docs_source}" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
