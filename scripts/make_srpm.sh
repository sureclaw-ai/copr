#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: make_srpm.sh --spec <path> --outdir <path>
EOF
}

spec=""
outdir=""
package_name="${PACKAGE_NAME:-gogcli}"
upstream_url="${UPSTREAM_URL:-https://github.com/openclaw/gogcli.git}"
upstream_tag_prefix="${UPSTREAM_TAG_PREFIX:-v}"
go_version_compat="${GO_VERSION_COMPAT:-}"

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

rewrite_go_directive() {
  # $1 = path to go.mod, $2 = compat go version (e.g. 1.25)
  _gomod="$1"
  _compat="$2"
  _tmp="${_gomod}.tmp"
  awk -v compat="$_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "$_gomod" >"$_tmp" || {
    rm -f "$_tmp"
    echo "Unable to update go directive in $_gomod" >&2
    exit 1
  }
  mv "$_tmp" "$_gomod"
}

strip_go_tools() {
  # Remove `tool` directives (single-line and block forms) from go.mod.
  # Tool directives (go 1.24+) pull in codegen/dev tools that are never needed
  # to build the release binary, but whose own modules can require a newer Go
  # than the target chroots ship. Dropping them keeps `go mod tidy` from
  # re-raising the go directive to satisfy those tools.
  _gomod="$1"
  _tmp="${_gomod}.tmp"
  awk '
    /^tool[ \t]*\(/ { inblock = 1; next }
    inblock && /^\)[ \t]*$/ { inblock = 0; next }
    inblock { next }
    /^tool[ \t]+[^ \t(]/ { next }
    { print }
  ' "$_gomod" >"$_tmp" && mv "$_tmp" "$_gomod"
}

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

srcdir="${workdir}/${package_name}-${version}"
sources_dir="${workdir}/sources"
mkdir -p "$sources_dir"

git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
commit="$(git -C "$srcdir" rev-parse --short=12 HEAD)"
date="$(TZ=UTC git -C "$srcdir" log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd HEAD)"

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  strip_go_tools "${srcdir}/go.mod"
  # Prune the now-unused tool dependencies from the require graph first, so the
  # subsequent `go mod tidy` no longer sees a dependency that demands a newer
  # Go. Then lower the go directive; the tidy below settles it at the compat
  # version because nothing left in the graph requires more.
  (
    cd "$srcdir"
    export GOFLAGS="-mod=mod"
    export GOWORK=off
    go mod tidy
  )
  rewrite_go_directive "${srcdir}/go.mod" "$go_version_compat"
fi

printf '%s\n' "$commit" >"${srcdir}/.copr-commit"
printf '%s\n' "$date" >"${srcdir}/.copr-date"
rm -rf "${srcdir}/.git"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod tidy
)

tar -C "$workdir" -czf "${sources_dir}/${package_name}-${version}.tar.gz" "${package_name}-${version}"

(
  cd "$srcdir"
  export GOFLAGS="-mod=mod"
  export GOWORK=off
  go mod vendor
)

tar -C "$srcdir" -czf "${sources_dir}/${package_name}-${version}-vendor.tar.gz" vendor

rpmbuild -bs "$spec" \
  --define "_sourcedir ${sources_dir}" \
  --define "_srcrpmdir ${outdir}"
