SHELL := /bin/sh

.PHONY: srpm

srpm:
	dnf -y install ca-certificates curl coreutils rpm-build xz
	../../scripts/make_node_srpm.sh --spec "$(spec)" --outdir "$(outdir)"
