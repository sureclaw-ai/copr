#!/usr/bin/env sh
set -eu

# Build an SRPM from per-architecture native binaries that upstream ships as
# platform-specific npm packages (rather than GitHub release assets). The CLI
# binary for each Linux architecture is pulled from its own npm package at the
# spec version, and documentation files are taken from the upstream git tag.

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Environment:
  PACKAGE_NAME         rpm package name (required)
  NPM_PACKAGE_X86_64   npm package carrying the linux x86_64 binary (required)
  NPM_PACKAGE_AARCH64  npm package carrying the linux aarch64 binary (required)
  NPM_BINARY_PATH      path to the binary inside the npm package root
                       (default: bin/<PACKAGE_NAME>)
  UPSTREAM_URL         upstream git repo used for documentation files (required)
  UPSTREAM_TAG_PREFIX  tag prefix for the docs checkout (default: v)
  DOC_FILES            space-separated docs copied from the tag
                       (default: "LICENSE README.md")
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
npm_binary_path="${NPM_BINARY_PATH:-}"
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

if [ -z "$npm_binary_path" ]; then
  npm_binary_path="bin/${package_name}"
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

versions = metadata.get("versions", {})
if version not in versions:
    raise SystemExit(f"npm package {package} has no version {version}")

print(versions[version]["dist"]["tarball"])
PY
}

# Download an npm package's tarball for $version and extract the single binary
# it carries (npm tarballs unpack under a top-level "package/" directory) into a
# bare source file named after the rpm arch suffix.
stage_binary() {
  npm_package="$1"
  arch_suffix="$2"
  output_path="${sources_dir}/${package_name}-${version}-${arch_suffix}"

  tarball_url="$(npm_tarball_url "$npm_package" "$version")"
  tgz="${workdir}/${arch_suffix}.tgz"
  curl -fsSL "$tarball_url" -o "$tgz"

  extract_dir="${workdir}/${arch_suffix}-extract"
  mkdir -p "$extract_dir"
  tar -xzf "$tgz" -C "$extract_dir"

  binary_src="${extract_dir}/package/${npm_binary_path}"
  if [ ! -f "$binary_src" ]; then
    echo "binary ${npm_binary_path} not found in ${npm_package}@${version}" >&2
    exit 1
  fi
  install -Dpm0755 "$binary_src" "$output_path"
}

stage_binary "$npm_package_x86_64" "linux-x64"
stage_binary "$npm_package_aarch64" "linux-arm64"

tag="${upstream_tag_prefix}${version}"
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
