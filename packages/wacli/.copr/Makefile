SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	UPSTREAM_URL="https://github.com/openclaw/wacli.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="wacli" \
	GO_VERSION_COMPAT="1.25" \
	GO_VERSION_COMPAT_ENFORCE="1" \
	GO_DROP_TOOL_DIRECTIVES="1" \
	../../scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
