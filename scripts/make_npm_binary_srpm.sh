#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Builds an SRPM for a project that ships prebuilt, per-architecture CLI
binaries as npm packages (one package per arch, each containing the binary
under package/bin/). The per-arch npm tarballs are downloaded, the binary is
extracted and repackaged into ${PACKAGE_NAME}-${version}-${arch}.tar.gz, and a
docs tarball is assembled from the upstream git checkout. This mirrors the
source layout produced by make_binary_release_srpm.sh so the spec is
unchanged.

Environment:
  PACKAGE_NAME          Package name (required)
  NPM_PACKAGE_X86_64    npm package holding the x86_64 binary (required)
  NPM_PACKAGE_AARCH64   npm package holding the aarch64 binary (required)
  BINARY_NAME           Binary file name inside the tarballs (default: PACKAGE_NAME)
  BINARY_PATH           Path to the binary inside the npm package
                        (default: package/bin/BINARY_NAME)
  UPSTREAM_URL          Upstream git URL for the docs checkout (required)
  UPSTREAM_TAG_PREFIX   Tag prefix (default: v)
  DOC_FILES             Space-separated doc files to include (default: LICENSE README.md)
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
binary_name="${BINARY_NAME:-$package_name}"
binary_path="${BINARY_PATH:-package/bin/${binary_name}}"
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

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
docsdir="${workdir}/${package_name}-${version}-docs"
mkdir -p "$sources_dir" "$docsdir"

resolve_npm_tarball() {
  npm_package="$1"
  wanted_version="$2"
  python3 - "$npm_package" "$wanted_version" <<'PY'
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

# Download an arch-specific npm package, extract its binary, and repackage it
# as ${package_name}-${version}-${arch}.tar.gz containing just the binary named
# ${binary_name} at the tarball root (matching what the spec extracts).
package_arch_binary() {
  npm_package="$1"
  arch="$2"
  tarball_url="$(resolve_npm_tarball "$npm_package" "$version")"

  pkgdir="${workdir}/npm-${arch}"
  mkdir -p "$pkgdir"
  curl -fsSL "$tarball_url" -o "${pkgdir}/pkg.tgz"
  tar -C "$pkgdir" -xzf "${pkgdir}/pkg.tgz"

  if [ ! -f "${pkgdir}/${binary_path}" ]; then
    echo "Binary ${binary_path} not found in ${npm_package} ${version}" >&2
    exit 1
  fi

  stagedir="${workdir}/stage-${arch}"
  mkdir -p "$stagedir"
  cp "${pkgdir}/${binary_path}" "${stagedir}/${binary_name}"
  chmod 0755 "${stagedir}/${binary_name}"
  tar -C "$stagedir" -czf \
    "${sources_dir}/${package_name}-${version}-${arch}.tar.gz" "${binary_name}"
}

package_arch_binary "$npm_package_x86_64" "x86_64"
package_arch_binary "$npm_package_aarch64" "aarch64"

srcdir="${workdir}/${package_name}-${version}-src"
git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "$docsdir" -czf "${sources_dir}/${package_name}-${version}-docs.tar.gz" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
