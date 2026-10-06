#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_opencode_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="opencode"
npm_package="opencode-ai"

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

# opencode is a Bun single-file executable distributed on npm. The npm meta
# package `opencode-ai` carries LICENSE (used for Source0); the prebuilt native
# binaries live in per-platform optionalDependency packages. We fetch the meta
# tarball plus the two Linux platform packages at the same version, extract each
# platform binary (package/bin/opencode), and verify the npm sha512 integrity
# and that each extracted file is a non-empty ELF executable.
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

# npm platform package -> extracted binary destination (Source1/Source2).
download_platform_binary() {
  npm_platform_package="$1"
  output_name="$2"
  output_path="${sources_dir}/${output_name}"
  tarball_path="${workdir}/${npm_platform_package}.tgz"
  extract_dir="${workdir}/${npm_platform_package}"

  python3 - "$npm_platform_package" "$version" "$tarball_path" <<'PY'
import base64
import hashlib
import json
import sys
import urllib.parse
import urllib.request

package, version, output = sys.argv[1:]
url = "https://registry.npmjs.org/" + urllib.parse.quote(package, safe="")
with urllib.request.urlopen(url) as response:
    metadata = json.load(response)

dist = metadata["versions"][version]["dist"]
tarball_url = dist["tarball"]
with urllib.request.urlopen(tarball_url) as response:
    data = response.read()

integrity = dist.get("integrity", "")
if integrity.startswith("sha512-"):
    expected = base64.b64decode(integrity[len("sha512-"):])
    actual = hashlib.sha512(data).digest()
    if actual != expected:
        raise SystemExit(f"{package} integrity mismatch for {version}")
else:
    raise SystemExit(f"{package} is missing a sha512 integrity for {version}")

with open(output, "wb") as file:
    file.write(data)
PY

  mkdir -p "$extract_dir"
  tar -xzf "$tarball_path" -C "$extract_dir" package/bin/opencode
  cp "${extract_dir}/package/bin/opencode" "$output_path"
  chmod 0755 "$output_path"

  # Sanity check: non-empty ELF executable.
  if [ ! -s "$output_path" ]; then
    echo "${output_name} is empty" >&2
    exit 1
  fi
  if [ "$(head -c 4 "$output_path")" != "$(printf '\177ELF')" ]; then
    echo "${output_name} is not an ELF executable" >&2
    exit 1
  fi
}

download_platform_binary "opencode-linux-x64-baseline" "${package_name}-${version}-linux-x64"
download_platform_binary "opencode-linux-arm64" "${package_name}-${version}-linux-arm64"

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
