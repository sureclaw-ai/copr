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
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
npm_binary_path="${NPM_BINARY_PATH:-package/bin/${package_name}}"
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

if [ -z "$spec" ] || [ -z "$outdir" ] || [ -z "$package_name" ] || [ -z "$upstream_url" ] || [ -z "$npm_package_x86_64" ] || [ -z "$npm_package_aarch64" ]; then
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

resolve_npm_tarball_url() {
  npm_package="$1"
  python3 - "$npm_package" "$version" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

package, version = sys.argv[1], sys.argv[2]
url = "https://registry.npmjs.org/" + urllib.parse.quote(package, safe="")
with urllib.request.urlopen(url) as response:
    metadata = json.load(response)

print(metadata["versions"][version]["dist"]["tarball"])
PY
}

build_arch_tarball() {
  arch="$1"
  npm_package="$2"
  tarball_url="$(resolve_npm_tarball_url "$npm_package")"

  tgz="${workdir}/${package_name}-${version}-${arch}.tgz"
  extractdir="${workdir}/${package_name}-${version}-${arch}-extract"
  stagedir="${workdir}/${package_name}-${version}-${arch}-stage"
  mkdir -p "$extractdir" "$stagedir"

  curl_download "$tarball_url" "$tgz"
  tar -xzf "$tgz" -C "$extractdir" "$npm_binary_path"
  cp "${extractdir}/${npm_binary_path}" "${stagedir}/${package_name}"
  chmod 0755 "${stagedir}/${package_name}"
  tar -C "$stagedir" -czf "${sources_dir}/${package_name}-${version}-${arch}.tar.gz" "${package_name}"
}

build_arch_tarball x86_64 "$npm_package_x86_64"
build_arch_tarball aarch64 "$npm_package_aarch64"

git clone --depth 1 --branch "${tag}" "${upstream_url}" "${srcdir}"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
