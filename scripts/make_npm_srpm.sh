#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: make_npm_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
npm_package="${NPM_PACKAGE:-}"

while [[ $# -gt 0 ]]; do
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

if [[ -z "$spec" || -z "$outdir" || -z "$package_name" || -z "$npm_package" ]]; then
  usage >&2
  exit 1
fi

spec="$(realpath "$spec")"
mkdir -p "$outdir"
outdir="$(realpath "$outdir")"

version="$(awk '$1 == "Version:" { print $2; exit }' "$spec")"
if [[ -z "$version" ]]; then
  echo "Unable to determine version from $spec" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
sources_dir="${workdir}/sources"
mkdir -p "$sources_dir"

tarball_url="$(
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
)"

curl -fsSL "$tarball_url" -o "${sources_dir}/${package_name}-${version}.tgz"

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
