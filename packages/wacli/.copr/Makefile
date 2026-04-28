SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	UPSTREAM_URL="https://github.com/steipete/wacli.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="wacli" \
	../../scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
