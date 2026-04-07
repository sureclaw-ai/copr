SHELL := /bin/bash

.PHONY: srpm

srpm:
	@if [[ -z "$(spec)" ]]; then \
		echo "spec is required" >&2; \
		exit 1; \
	fi
	@pkg_dir="$$(dirname "$(spec)")"; \
	pkg_makefile="$$pkg_dir/.copr/Makefile"; \
	if [[ ! -f "$$pkg_makefile" ]]; then \
		echo "missing package COPR makefile: $$pkg_makefile" >&2; \
		exit 1; \
	fi; \
	exec $(MAKE) -C "$$pkg_dir" -f .copr/Makefile srpm outdir="$(outdir)" spec="$(spec)"
