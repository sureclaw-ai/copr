#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
npm_pkg_x86_64="${NPM_PKG_X86_64:-}"
npm_pkg_aarch64="${NPM_PKG_AARCH64:-}"
doc_files="${DOC_FILES:-LICENSE README.md}"

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

if [ -z "$spec" ] || [ -z "$outdir" ] || [ -z "$package_name" ] || [ -z "$upstream_url" ] || [ -z "$npm_pkg_x86_64" ] || [ -z "$npm_pkg_aarch64" ]; then
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

release_source_x86_64="${RELEASE_SOURCE_X86_64:-${package_name}-${version}-x86_64.tar.gz}"
release_source_aarch64="${RELEASE_SOURCE_AARCH64:-${package_name}-${version}-aarch64.tar.gz}"
docs_source="${DOCS_SOURCE:-${package_name}-${version}-docs.tar.gz}"

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
srcdir="${workdir}/${package_name}-${version}-src"
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

# Download the npm scoped package tarball for a given arch and repackage it as
# a tarball containing the `opencode` executable at the top level, matching the
# spec's %prep/%install contract.
repackage_npm_binary() {
  npm_pkg="$1"
  output_name="$2"
  base="${npm_pkg##*/}"
  url="https://registry.npmjs.org/${npm_pkg}/-/${base}-${version}.tgz"

  tgz_path="${workdir}/${base}-${version}.tgz"
  extract_dir="${workdir}/${base}-extract"
  stage_dir="${workdir}/${base}-stage"
  rm -rf "$extract_dir" "$stage_dir"
  mkdir -p "$extract_dir" "$stage_dir"

  curl_download "$url" "$tgz_path"
  tar -C "$extract_dir" -xzf "$tgz_path" "package/bin/${package_name}"

  cp "${extract_dir}/package/bin/${package_name}" "${stage_dir}/${package_name}"
  chmod 0755 "${stage_dir}/${package_name}"
  tar -C "$stage_dir" -czf "${sources_dir}/${output_name}" "${package_name}"
}

repackage_npm_binary "${npm_pkg_x86_64}" "${release_source_x86_64}"
repackage_npm_binary "${npm_pkg_aarch64}" "${release_source_aarch64}"

git clone --depth 1 --branch "${tag}" "${upstream_url}" "${srcdir}"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${docs_source}" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
