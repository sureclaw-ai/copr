#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_npm_binary_srpm.sh --spec <path> --outdir <path>

Builds a binary SRPM from prebuilt binaries published to the npm registry.

Environment variables:
  PACKAGE_NAME         rpm package name (required)
  UPSTREAM_URL         upstream git URL, used to clone docs (required)
  UPSTREAM_TAG_PREFIX  git tag prefix (default: v)
  NPM_SCOPE            npm scope, e.g. @opencode (required)
  NPM_PACKAGE_X86_64   scoped-package basename for x86_64 (required)
  NPM_PACKAGE_AARCH64  scoped-package basename for aarch64 (required)
  NPM_BINARY_PATH      path of the binary inside the npm "package/" dir
                       (default: bin/opencode)
  DOC_FILES            files copied from the git tag into the docs tarball
                       (default: LICENSE README.md)
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
npm_scope="${NPM_SCOPE:-}"
npm_package_x86_64="${NPM_PACKAGE_X86_64:-}"
npm_package_aarch64="${NPM_PACKAGE_AARCH64:-}"
npm_binary_path="${NPM_BINARY_PATH:-bin/opencode}"
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

if [ -z "$spec" ] || [ -z "$outdir" ] || [ -z "$package_name" ] || [ -z "$upstream_url" ] || [ -z "$npm_scope" ] || [ -z "$npm_package_x86_64" ] || [ -z "$npm_package_aarch64" ]; then
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

# Name of the binary as it must appear at the root of the produced tarball
# (derived from NPM_BINARY_PATH so the spec's %install stays unchanged).
binary_basename="$(basename "$npm_binary_path")"

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

# Download an npm platform tarball, extract the binary from "package/<path>"
# and repackage it as an archive containing the binary at its root.
build_arch_source() {
  npm_package="$1"
  output_name="$2"

  # No-auth tarball endpoint:
  #   https://registry.npmjs.org/<scope>/<package>/-/<package>-<version>.tgz
  # (the download path uses the literal scope, e.g. @opencode/).
  tarball_url="https://registry.npmjs.org/${npm_scope}/${npm_package}/-/${npm_package}-${version}.tgz"
  npm_tgz="${workdir}/${npm_package}-${version}.tgz"
  extract_dir="${workdir}/npm-${npm_package}"
  stage_dir="${workdir}/stage-${npm_package}"

  curl_download "${tarball_url}" "${npm_tgz}"

  rm -rf "$extract_dir" "$stage_dir"
  mkdir -p "$extract_dir" "$stage_dir"
  tar -C "$extract_dir" -xzf "$npm_tgz"

  binary_src="${extract_dir}/package/${npm_binary_path}"
  if [ ! -f "$binary_src" ]; then
    echo "Expected binary not found: package/${npm_binary_path} in ${npm_package}" >&2
    exit 1
  fi

  install -Dpm0755 "$binary_src" "${stage_dir}/${binary_basename}"
  tar -C "$stage_dir" -czf "${sources_dir}/${output_name}" "${binary_basename}"
}

build_arch_source "${npm_package_x86_64}" "${release_source_x86_64}"
build_arch_source "${npm_package_aarch64}" "${release_source_aarch64}"

git clone --depth 1 --branch "${tag}" "${upstream_url}" "${srcdir}"
for doc_file in ${doc_files}; do
  cp "${srcdir}/${doc_file}" "${docsdir}/"
done
tar -C "${docsdir}" -czf "${sources_dir}/${docs_source}" .

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
