SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install curl python3 tar rpm-build
	../../scripts/make_opencode_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
