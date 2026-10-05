#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Builds a source RPM for a package whose prebuilt executables are distributed as
per-architecture npm packages (each shipping the binary under package/bin/).
The x86_64 and aarch64 npm tarballs are downloaded from the npm registry, the
binary is extracted from each, and repackaged as
<name>-<version>-<arch>.tar.gz with the binary at the top level so the spec can
consume them exactly like release-tarball sources. Documentation files are taken
from the upstream git tag and packaged as <name>-<version>-docs.tar.gz.

Environment:
  PACKAGE_NAME         rpm package name (required)
  NPM_PACKAGE_X86_64   npm package providing the x86_64 binary (required)
  NPM_PACKAGE_AARCH64  npm package providing the aarch64 binary (required)
  BINARY_NAME          executable name inside package/bin (default: PACKAGE_NAME)
  UPSTREAM_URL         upstream git repo used for documentation (required)
  UPSTREAM_TAG_PREFIX  git tag prefix (default: v)
  DOC_FILES            space-separated docs to copy (default: "LICENSE README.md")
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
binary_name="${BINARY_NAME:-$package_name}"
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

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
mkdir -p "$sources_dir"

npm_tarball_url() {
  python3 - "$1" "$2" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

package, version = sys.argv[1], sys.argv[2]
url = "https://registry.npmjs.org/" + urllib.parse.quote(package, safe="")
with urllib.request.urlopen(url) as response:
    metadata = json.load(response)

versions = metadata.get("versions", {})
if version not in versions:
    sys.exit(f"npm package {package} has no version {version}")
print(versions[version]["dist"]["tarball"])
PY
}

# Download the per-arch npm package, pull the executable out of package/bin and
# repackage it with the binary at the archive root.
build_arch_tarball() {
  arch="$1"
  npm_package="$2"

  tarball_url="$(npm_tarball_url "$npm_package" "$version")"

  extract_dir="${workdir}/${arch}-extract"
  stage_dir="${workdir}/${arch}-stage"
  rm -rf "$extract_dir" "$stage_dir"
  mkdir -p "$extract_dir" "$stage_dir"

  curl -fsSL "$tarball_url" -o "${workdir}/${arch}.tgz"
  tar -xzf "${workdir}/${arch}.tgz" -C "$extract_dir"

  bin_path="${extract_dir}/package/bin/${binary_name}"
  if [ ! -f "$bin_path" ]; then
    echo "Expected binary not found in ${npm_package}: package/bin/${binary_name}" >&2
    exit 1
  fi

  cp "$bin_path" "${stage_dir}/${binary_name}"
  chmod 0755 "${stage_dir}/${binary_name}"
  tar -C "$stage_dir" -czf \
    "${sources_dir}/${package_name}-${version}-${arch}.tar.gz" "${binary_name}"
}

build_arch_tarball x86_64 "$npm_package_x86_64"
build_arch_tarball aarch64 "$npm_package_aarch64"

# Documentation is not shipped in the npm binary packages, so take it from the
# upstream git tag.
tag="${upstream_tag_prefix}${version}"
srcdir="${workdir}/${package_name}-${version}-src"
docsdir="${workdir}/${package_name}-${version}-docs"
mkdir -p "$docsdir"

git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
for doc_file in $doc_files; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "$docsdir" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
