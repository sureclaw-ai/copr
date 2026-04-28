#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_claude_code_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="claude-code"
npm_package="@anthropic-ai/claude-code"
download_base_url="https://downloads.claude.ai/claude-code-releases"

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

if [ -z "$spec" ] || [ -z "$outdir" ]; then
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

python3 - "$npm_package" "$version" "${sources_dir}/${package_name}-${version}.tgz" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

package, version, output = sys.argv[1:]
url = "https://registry.npmjs.org/" + urllib.parse.quote(package, safe="")
with urllib.request.urlopen(url) as response:
    metadata = json.load(response)

tarball_url = metadata["versions"][version]["dist"]["tarball"]
with urllib.request.urlopen(tarball_url) as response, open(output, "wb") as file:
    file.write(response.read())
PY

manifest="${workdir}/manifest.json"
curl -fsSL "${download_base_url}/${version}/manifest.json" -o "$manifest"

for platform in linux-x64 linux-arm64; do
  output="${sources_dir}/${package_name}-${version}-${platform}"
  curl -fsSL "${download_base_url}/${version}/${platform}/claude" -o "$output"
  python3 - "$manifest" "$platform" "$output" <<'PY'
import hashlib
import json
import sys

manifest_path, platform, binary_path = sys.argv[1:]
with open(manifest_path, "r", encoding="utf-8") as file:
    manifest = json.load(file)

expected = manifest["platforms"][platform]["checksum"]
digest = hashlib.sha256()
with open(binary_path, "rb") as file:
    for chunk in iter(lambda: file.read(1024 * 1024), b""):
        digest.update(chunk)

actual = digest.hexdigest()
if actual != expected:
    raise SystemExit(
        f"{platform} checksum mismatch: expected {expected}, got {actual}"
    )
PY
done

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
