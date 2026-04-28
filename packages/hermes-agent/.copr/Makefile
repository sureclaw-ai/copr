SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install git python3 rpm-build
	UPSTREAM_URL="https://github.com/NousResearch/hermes-agent.git" \
	UPSTREAM_TAG_PREFIX="v" \
	UPSTREAM_TAG_VERSION_PATTERN="[0-9][0-9][0-9][0-9].[0-9]*.[0-9]*" \
	PACKAGE_NAME="hermes-agent" \
	../../scripts/make_python_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
