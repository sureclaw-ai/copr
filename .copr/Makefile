SHELL := /bin/bash

.PHONY: srpm

srpm:
	dnf -y install git golang rpm-build
	./scripts/make_srpm.sh --spec "$(spec)" --outdir "$(outdir)"

