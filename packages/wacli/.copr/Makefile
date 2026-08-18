SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	UPSTREAM_URL="https://github.com/openclaw/wacli.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="wacli" \
	GO_VERSION_COMPAT="1.25" \
	GO_DROP_TOOLS="github.com/sqlc-dev/sqlc/cmd/sqlc" \
	GO_DROP_REQUIRES="github.com/sqlc-dev/sqlc" \
	../../scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
