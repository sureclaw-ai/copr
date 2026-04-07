SHELL := /bin/bash

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	UPSTREAM_URL="https://github.com/steipete/gogcli.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="gogcli" \
	../../scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"

