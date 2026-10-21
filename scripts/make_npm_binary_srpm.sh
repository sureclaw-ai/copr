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
npm_scope="${NPM_SCOPE:-}"
npm_target_x86_64="${NPM_TARGET_X86_64:-}"
npm_target_aarch64="${NPM_TARGET_AARCH64:-}"
npm_binary_path="${NPM_BINARY_PATH:-package/bin/${package_name}}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
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

if [ -z "$spec" ] || [ -z "$outdir" ] || [ -z "$package_name" ] || [ -z "$npm_scope" ] || [ -z "$npm_target_x86_64" ] || [ -z "$npm_target_aarch64" ] || [ -z "$upstream_url" ]; then
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
mkdir -p "$sources_dir"

# Resolve the download URL for a published npm package version.
npm_tarball_url() {
  npm_package="$1"
  npm_version="$2"
  python3 - "$npm_package" "$npm_version" <<'PY'
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

# Download the per-platform npm package, extract the prebuilt binary, and
# repackage it as the bare binary the spec extracts into its build dir.
make_binary_source() {
  arch="$1"
  npm_target="$2"
  npm_package="${npm_scope}/${npm_target}"
  tarball_url="$(npm_tarball_url "$npm_package" "$version")"

  pkg_dir="${workdir}/${arch}"
  mkdir -p "$pkg_dir"
  curl -fsSL "$tarball_url" -o "${pkg_dir}/pkg.tgz"
  tar -C "$pkg_dir" -xzf "${pkg_dir}/pkg.tgz"

  binary="${pkg_dir}/${npm_binary_path}"
  if [ ! -f "$binary" ]; then
    echo "Expected binary ${npm_binary_path} missing from ${npm_package}@${version}" >&2
    exit 1
  fi

  stage_dir="${workdir}/stage-${arch}"
  mkdir -p "$stage_dir"
  cp "$binary" "${stage_dir}/${package_name}"
  chmod 0755 "${stage_dir}/${package_name}"
  tar -C "$stage_dir" -czf "${sources_dir}/${package_name}-${version}-${arch}.tar.gz" "${package_name}"
}

make_binary_source "x86_64" "$npm_target_x86_64"
make_binary_source "aarch64" "$npm_target_aarch64"

# Documentation (LICENSE, README, ...) is not shipped in the npm runtime
# packages, so take it from the upstream git tag.
docsdir="${workdir}/${package_name}-${version}-docs"
srcdir="${workdir}/${package_name}-${version}-src"
mkdir -p "$docsdir"
git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
for doc_file in $doc_files; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "$docsdir" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
