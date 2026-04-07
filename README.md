# COPR packaging

This repository packages upstream CLI tools for COPR.

Each package lives in its own subdirectory under `packages/` and is built in its own canonical COPR project. An umbrella COPR named `ai` is maintained separately and only enables those canonical package repos via runtime dependencies, so it does not rebuild the same RPMs.

## Packages

- `gogcli`: source-built from upstream git tags with vendored Go modules
- `codex`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`, with a runtime dependency on `ripgrep`
- `opencode`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`
- `claude-code`: repackaged from the `@anthropic-ai/claude-code` npm tarball for `x86_64` and `aarch64`, with a Node.js runtime wrapper for the upstream `claude` command
- `ai`: umbrella COPR project that enables the canonical package COPRs together

## What is included

- `packages/<name>/`: per-package spec and `.copr/Makefile`
- `packages.json`: package list used by the updater workflow
- `pyproject.toml` and `uv.lock`: pinned Python tooling for the GitHub workflow
- `scripts/make_srpm.sh`: clones an upstream git tag, vendors Go modules, and emits an SRPM
- `scripts/make_binary_release_srpm.sh`: downloads release artifacts and emits an SRPM
- `scripts/make_npm_srpm.sh`: downloads an npm package tarball and emits an SRPM
- `scripts/ensure_copr.py`: creates or updates the COPR project and package source definition
- `.github/workflows/update-copr.yml`: daily upstream check plus optional manual rebuild

## GitHub configuration

Add these repository variables:

- `COPR_OWNER`: COPR owner, for example `yourname` or `@your-group`
- `COPR_URL` (optional): defaults to `https://copr.fedorainfracloud.org`

Add these repository secrets:

- `COPR_LOGIN`
- `COPR_USERNAME`
- `COPR_TOKEN`

The workflow runs daily at `00:15` UTC and can also be started manually. Use the manual run with `force_build=true` for the first bootstrap build or to rebuild the currently packaged version.

## How the workflow behaves

1. Checks the latest upstream `v*` tag from `https://github.com/steipete/gogcli.git`.
2. Checks the latest upstream `rust-v*` tag from `https://github.com/openai/codex.git`.
3. Checks the latest upstream `v*` tag from `https://github.com/anomalyco/opencode.git`.
4. Checks the latest npm `latest` dist-tag for `@anthropic-ai/claude-code`.
5. Uses `uv` to install the pinned Python toolchain and workflow dependencies from `uv.lock`.
6. Checks all tracked upstream sources concurrently, updates any package spec whose upstream version changed, and pushes that commit back to this repository.
7. Ensures each canonical package COPR project exists, enables all currently available COPR chroots for that package's configured architectures, and turns on `follow-fedora-branching`.
8. Ensures every package source points at this repository and uses the `make_srpm` method from its package subdirectory.
9. Ensures the umbrella COPR project `ai` exists and carries runtime dependencies on the canonical package COPRs.
10. Starts COPR builds only for canonical package projects whose versions changed, or for all canonical package projects when the manual workflow is run with `force_build=true`.

## Notes

- The COPR project chroots are synced from the live `copr-cli list-chroots` output, filtered to chroots whose architecture appears in `packages.json`.
- All tracked packages currently target `aarch64` and `x86_64`. That includes Fedora plus any EPEL, CentOS Stream, or openSUSE chroots COPR currently exposes for those architectures.
- `gogcli` uses vendored Go modules.
- `codex` uses the upstream Linux musl release artifacts and depends on the Fedora `ripgrep` package instead of bundling `rg`.
- `opencode` uses the upstream Linux release artifacts and packages the `x86_64` baseline build so one RPM works on a wider range of Fedora systems.
- `claude-code` uses the upstream npm tarball and installs the upstream `claude` command name.
- `claude-code` is proprietary software distributed under Anthropic's legal terms rather than an open-source license; review those terms before publishing it in a public COPR.
- The umbrella `ai` COPR does not rebuild packages; it only points users at the canonical per-package repos through `copr://...` runtime dependencies.
