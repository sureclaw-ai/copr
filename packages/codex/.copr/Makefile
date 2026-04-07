SHELL := /bin/bash

.PHONY: srpm

srpm:
	dnf -y install curl git rpm-build
	UPSTREAM_URL="https://github.com/openai/codex.git" \
	UPSTREAM_TAG_PREFIX="rust-v" \
	PACKAGE_NAME="codex" \
	RELEASE_ASSET_X86_64="codex-x86_64-unknown-linux-musl.tar.gz" \
	RELEASE_ASSET_AARCH64="codex-aarch64-unknown-linux-musl.tar.gz" \
	DOC_FILES="LICENSE NOTICE README.md" \
	../../scripts/make_binary_release_srpm.sh --spec "$(spec)" --outdir "$(outdir)"

