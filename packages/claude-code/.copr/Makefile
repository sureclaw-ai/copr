SHELL := /bin/bash

.PHONY: srpm

srpm:
	dnf -y install curl python3 rpm-build
	NPM_PACKAGE="@anthropic-ai/claude-code" \
	PACKAGE_NAME="claude-code" \
	../../scripts/make_npm_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
