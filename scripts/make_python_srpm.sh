#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: make_python_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-}"
upstream_url="${UPSTREAM_URL:-}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
upstream_tag_version_pattern="${UPSTREAM_TAG_VERSION_PATTERN:-[0-9][0-9][0-9][0-9].[0-9]*.[0-9]*}"

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

if [[ -z "$spec" || -z "$outdir" || -z "$package_name" || -z "$upstream_url" ]]; then
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
srcdir="${workdir}/${package_name}-${version}"
mkdir -p "$sources_dir"

candidate_tags="$(
  git ls-remote --tags --refs "$upstream_url" |
    awk -v prefix="$upstream_tag_prefix" -v pattern="$upstream_tag_version_pattern" '
      {
        ref = $2
        sub("^refs/tags/", "", ref)
        if (ref ~ "^" prefix pattern "$") print ref
      }
    ' |
    sort -Vr
)"

if [[ -z "$candidate_tags" ]]; then
  echo "Unable to determine matching tags from $upstream_url" >&2
  exit 1
fi

source_version_for_pyproject() {
  python3 - "$1" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    print(tomllib.load(handle)["project"]["version"])
PY
}

selected_tag=""
while IFS= read -r candidate_tag; do
  rm -rf "$srcdir"
  git clone --depth 1 --branch "$candidate_tag" "$upstream_url" "$srcdir"
  source_version="$(source_version_for_pyproject "$srcdir/pyproject.toml")"
  if [[ "$source_version" == "$version" ]]; then
    selected_tag="$candidate_tag"
    break
  fi
done <<<"$candidate_tags"

if [[ -z "$selected_tag" ]]; then
  echo "Unable to find an upstream tag for pyproject version $version" >&2
  exit 1
fi

commit="$(git -C "$srcdir" rev-parse --short=12 HEAD)"
date="$(TZ=UTC git -C "$srcdir" log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd HEAD)"

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
printf '%s\n' "$selected_tag" >"${srcdir}/.copr-tag"
rm -rf "${srcdir}/.git"

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
