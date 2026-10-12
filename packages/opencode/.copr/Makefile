SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install curl git rpm-build
	UPSTREAM_URL="https://github.com/anomalyco/opencode.git" \
	PACKAGE_NAME="opencode" \
	NPM_PACKAGE_X86_64="@opencode/cli-linux-x64-baseline" \
	NPM_PACKAGE_AARCH64="@opencode/cli-linux-arm64" \
	DOC_FILES="LICENSE README.md" \
	../../scripts/make_npm_binary_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
