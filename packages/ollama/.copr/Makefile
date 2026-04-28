SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install curl git rpm-build
	UPSTREAM_URL="https://github.com/ollama/ollama.git" \
	UPSTREAM_TAG_PREFIX="v" \
	PACKAGE_NAME="ollama" \
	RELEASE_ASSET_X86_64="ollama-linux-amd64.tar.zst" \
	RELEASE_ASSET_AARCH64="ollama-linux-arm64.tar.zst" \
	DOC_FILES="LICENSE README.md" \
	../../scripts/make_binary_release_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
