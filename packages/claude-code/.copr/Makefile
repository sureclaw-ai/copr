SHELL := /bin/bash

.PHONY: srpm

srpm:
	dnf -y install curl python3 rpm-build
	../../scripts/make_claude_code_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
