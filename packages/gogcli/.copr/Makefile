SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	UPSTREAM_URL="https://github.com/steipete/gogcli.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="gogcli" \
	GO_VERSION_COMPAT="1.25" \
	../../scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
