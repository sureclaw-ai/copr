SHELL := /bin/bash

.PHONY: srpm

srpm:
	@if [[ -z "$(spec)" ]]; then \
		echo "spec is required" >&2; \
		exit 1; \
	fi
	@pkg_makefile="$$(dirname "$(spec)")/.copr/Makefile"; \
	if [[ ! -f "$$pkg_makefile" ]]; then \
		echo "missing package COPR makefile: $$pkg_makefile" >&2; \
		exit 1; \
	fi; \
	exec $(MAKE) -f "$$pkg_makefile" srpm outdir="$(outdir)" spec="$(spec)"
