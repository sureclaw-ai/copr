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
go_strip_tool_directives="${GO_STRIP_TOOL_DIRECTIVES:-}"
go_strip_require_prefixes="${GO_STRIP_REQUIRE_PREFIXES:-}"

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

tag="${upstream_tag_prefix}${version}"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

srcdir="${workdir}/${package_name}-${version}"
sources_dir="${workdir}/sources"
mkdir -p "$sources_dir"

git clone --depth 1 --branch "$tag" "$upstream_url" "$srcdir"
commit="$(git -C "$srcdir" rev-parse --short=12 HEAD)"
date="$(TZ=UTC git -C "$srcdir" log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd HEAD)"

# Optionally strip Go `tool` directives (a Go 1.24+ dev-tooling feature) and
# selected `require` entries from go.mod before vendoring. Tool dependencies are
# never needed to compile the release binary, but `go mod tidy`/`vendor` still
# resolve them and their transitive graph. When such a tool pins a newer `go`
# directive than the build chroots ship, it drags the whole module's required Go
# version up (tidy will not let the main module's `go` line sit below any
# dependency's requirement), which breaks the vendored, offline chroot build on
# distros that lag the newest toolchain. Removing the tool graph keeps the build
# reproducible on the lowest supported Go.
if [ -n "$go_strip_tool_directives" ] || [ -n "$go_strip_require_prefixes" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_STRIP_* was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk -v strip_tools="$go_strip_tool_directives" -v prefixes="$go_strip_require_prefixes" '
    BEGIN {
      n = split(prefixes, plist, /[ ,]+/)
    }
    # Drop a multi-line `tool ( ... )` block.
    strip_tools != "" && in_tool_block {
      if ($0 ~ /^\)/) { in_tool_block = 0 }
      next
    }
    strip_tools != "" && /^tool[ \t]*\(/ { in_tool_block = 1; next }
    # Drop a single-line `tool <path>` directive.
    strip_tools != "" && /^tool[ \t]+[^ \t(]/ { next }
    # Drop `require` lines (block or single-line form) matching a prefix.
    {
      line = $0
      trimmed = line
      sub(/^[ \t]+/, "", trimmed)
      sub(/^require[ \t]+/, "", trimmed)
      for (i = 1; i <= n; i++) {
        if (plist[i] != "" && index(trimmed, plist[i]) == 1) {
          next
        }
      }
      print line
    }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to strip directives from ${srcdir}/go.mod" >&2
    exit 1
  }
  mv "$go_mod_tmp" "${srcdir}/go.mod"
fi

if [ -n "$go_version_compat" ]; then
  if [ ! -f "${srcdir}/go.mod" ]; then
    echo "GO_VERSION_COMPAT was set but ${srcdir}/go.mod does not exist" >&2
    exit 1
  fi
  go_mod_tmp="${srcdir}/go.mod.tmp"
  awk -v compat="$go_version_compat" '
    /^go [0-9]+\.[0-9]+(\.[0-9]+)?$/ && !updated {
      print "go " compat
      updated = 1
      next
    }
    { print }
    END { if (!updated) exit 2 }
  ' "${srcdir}/go.mod" >"$go_mod_tmp" || {
    rm -f "$go_mod_tmp"
    echo "Unable to update go directive in ${srcdir}/go.mod" >&2
    exit 1
  }
  mv "$go_mod_tmp" "${srcdir}/go.mod"
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
