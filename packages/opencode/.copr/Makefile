SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install curl git rpm-build
	UPSTREAM_URL="https://github.com/anomalyco/opencode.git" \
	PACKAGE_NAME="opencode" \
	RELEASE_ASSET_X86_64="opencode-linux-x64-baseline.tar.gz" \
	RELEASE_ASSET_AARCH64="opencode-linux-arm64.tar.gz" \
	DOC_FILES="LICENSE README.md" \
	../../scripts/make_binary_release_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
