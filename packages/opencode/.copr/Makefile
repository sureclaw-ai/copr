SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install curl git tar rpm-build
	UPSTREAM_URL="https://github.com/anomalyco/opencode.git" \
	PACKAGE_NAME="opencode" \
	NPM_SCOPE="@opencode" \
	NPM_PACKAGE_X86_64="cli-linux-x64-baseline" \
	NPM_PACKAGE_AARCH64="cli-linux-arm64" \
	NPM_BINARY_PATH="bin/opencode" \
	DOC_FILES="LICENSE README.md" \
	../../scripts/make_npm_binary_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
