#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Builds an SRPM for a project that ships prebuilt, platform-specific binaries as
npm packages (one package per architecture) rather than as source or as GitHub
release assets. For each architecture the matching npm package is downloaded
from the registry, the compiled binary is extracted from it, and a
"<package>-<version>-<arch>.tar.gz" tarball containing just that binary (at the
archive root) is produced for the spec's Source0/Source1. Documentation files
are collected from the upstream git tag into "<package>-<version>-docs.tar.gz".

Environment variables:
  PACKAGE_NAME          Required. RPM package name (e.g. "opencode").
  NPM_PACKAGE_X86_64    Required. npm package providing the x86_64 binary
                        (e.g. "@opencode/cli-linux-x64-baseline").
  NPM_PACKAGE_AARCH64   Required. npm package providing the aarch64 binary
                        (e.g. "@opencode/cli-linux-arm64").
  BINARY_PATH           Path of the binary inside the npm package tarball.
                        Default: "package/bin/<PACKAGE_NAME>".
  BINARY_NAME           Name the binary is given inside the generated source
                        tarballs. Default: "<PACKAGE_NAME>".
  UPSTREAM_URL          Required. Upstream git repository (for the doc files).
  UPSTREAM_TAG_PREFIX   Git tag prefix for the version. Default: "v".
  DOC_FILES             Space-separated doc files to pull from the git tag.
                        Default: "LICENSE README.md".
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
binary_path="${BINARY_PATH:-}"
binary_name="${BINARY_NAME:-}"
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

binary_path="${binary_path:-package/bin/${package_name}}"
binary_name="${binary_name:-${package_name}}"

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

# Resolve the exact tarball URL for a given npm package + version from the
# registry metadata, so we follow whatever filename/host the registry uses.
npm_tarball_url() {
  python3 - "$1" "$2" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

package, version = sys.argv[1], sys.argv[2]
url = "https://registry.npmjs.org/" + urllib.parse.quote(package, safe="@")
with urllib.request.urlopen(url) as response:
    metadata = json.load(response)

versions = metadata.get("versions", {})
if version not in versions:
    raise SystemExit(
        f"npm package {package} has no version {version} "
        f"(available: {', '.join(sorted(versions)[-5:])})"
    )
print(versions[version]["dist"]["tarball"])
PY
}

# Download the npm package for an arch, extract the single binary, and repackage
# it as "<package>-<version>-<arch>.tar.gz" with the binary at the archive root
# (matching the spec's Source0/Source1 expectations).
build_arch_source() {
  arch="$1"
  npm_package="$2"
  arch_workdir="${workdir}/${arch}"
  mkdir -p "$arch_workdir"

  tarball_url="$(npm_tarball_url "$npm_package" "$version")"
  curl -fsSL "$tarball_url" -o "${arch_workdir}/package.tgz"

  tar -C "$arch_workdir" -xzf "${arch_workdir}/package.tgz" "$binary_path"
  if [ ! -f "${arch_workdir}/${binary_path}" ]; then
    echo "Expected binary ${binary_path} not found in ${npm_package}@${version}" >&2
    exit 1
  fi

  install -Dpm0755 "${arch_workdir}/${binary_path}" "${arch_workdir}/root/${binary_name}"
  tar -C "${arch_workdir}/root" -czf \
    "${sources_dir}/${package_name}-${version}-${arch}.tar.gz" "${binary_name}"
}

build_arch_source "x86_64" "$npm_package_x86_64"
build_arch_source "aarch64" "$npm_package_aarch64"

# Documentation comes from the upstream git tag (the npm packages ship only the
# binary).
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
