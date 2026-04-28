# COPR packaging

This repository packages upstream CLI tools for COPR.

Each package lives in its own subdirectory under `packages/` and is built in its own canonical COPR project. An umbrella COPR named `ai` is maintained separately and only enables those canonical package repos via runtime dependencies, so it does not rebuild the same RPMs.

## Build status

| Package | Status |
| --- | --- |
| `gogcli` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/gogcli/package/gogcli/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/gogcli/package/gogcli/) |
| `wacli` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/wacli/package/wacli/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/wacli/package/wacli/) |
| `codex` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/codex/package/codex/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/codex/package/codex/) |
| `opencode` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/opencode/package/opencode/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/opencode/package/opencode/) |
| `ollama` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/ollama/package/ollama/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/ollama/package/ollama/) |
| `claude-code` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/claude-code/package/claude-code/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/claude-code/package/claude-code/) |
| `hermes-agent` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/hermes-agent/package/hermes-agent/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/hermes-agent/package/hermes-agent/) |

## Packages

- `gogcli`: source-built from upstream git tags with vendored Go modules
- `wacli`: source-built from upstream git tags with vendored Go modules, with CGO enabled and the upstream `sqlite_fts5` build tag
- `codex`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`, with a runtime dependency on `ripgrep`
- `opencode`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`
- `ollama`: repackaged from upstream Linux release bundles for `x86_64` and `aarch64`
- `claude-code`: repackaged from the `@anthropic-ai/claude-code` npm tarball for `x86_64` and `aarch64`, with a Node.js runtime wrapper for the upstream `claude` command
- `hermes-agent`: packaged from upstream GitHub tags, with a launcher that creates a per-user Python virtual environment from the packaged source on first run
- `ai`: umbrella COPR project that enables the canonical package COPRs together

## What is included

- `packages/<name>/`: per-package spec and `.copr/Makefile`
- `packages.json`: package list used by the updater workflow
- `pyproject.toml` and `uv.lock`: pinned Python tooling for the GitHub workflow
- `scripts/make_srpm.sh`: clones an upstream git tag, vendors Go modules, and emits an SRPM
- `scripts/make_binary_release_srpm.sh`: downloads release artifacts and emits an SRPM
- `scripts/make_npm_srpm.sh`: downloads an npm package tarball and emits an SRPM
- `scripts/make_python_srpm.sh`: clones an upstream Python project tag and emits an SRPM
- `scripts/ensure_copr.py`: creates or updates the COPR project and package source definition
- `.github/workflows/update-copr.yml`: daily upstream check, rebuild on pushes to `main`, plus optional manual rebuild

## GitHub configuration

Add these repository variables:

- `COPR_OWNER`: COPR owner, for example `yourname` or `@your-group`
- `COPR_URL` (optional): defaults to `https://copr.fedorainfracloud.org`

Add these repository secrets:

- `COPR_LOGIN`
- `COPR_USERNAME`
- `COPR_TOKEN`

The workflow runs daily at `00:15` UTC, on pushes to `main`, and can also be started manually. Use the manual run with `force_build=true` for the first bootstrap build or to rebuild the currently packaged version.

## How the workflow behaves

1. Checks the latest upstream `v*` tag from `https://github.com/steipete/gogcli.git`.
2. Checks the latest upstream `v*` tag from `https://github.com/steipete/wacli.git`.
3. Checks the latest upstream `rust-v*` tag from `https://github.com/openai/codex.git`.
4. Checks the latest upstream `v*` tag from `https://github.com/anomalyco/opencode.git`.
5. Checks the latest upstream `v*` tag from `https://github.com/ollama/ollama.git`.
6. Checks the latest npm `latest` dist-tag for `@anthropic-ai/claude-code`.
7. Checks the latest date-style upstream tag from `https://github.com/NousResearch/hermes-agent.git` and reads its `pyproject.toml` version.
8. Uses `uv` to install the pinned Python toolchain and workflow dependencies from `uv.lock`.
9. Checks all tracked upstream sources concurrently, updates any package spec whose upstream version changed, and pushes that commit back to this repository.
10. Ensures each canonical package COPR project exists, enables all currently available COPR chroots for that package's configured architectures except excluded distros, and turns on `follow-fedora-branching`.
11. Ensures every package source points at this repository and uses the `make_srpm` method from its package subdirectory.
12. Ensures the umbrella COPR project `ai` exists and carries runtime dependencies on the canonical package COPRs.
13. Starts COPR builds only for canonical package projects whose versions changed, or for all canonical package projects when the manual workflow is run with `force_build=true`.

## Notes

- The COPR project chroots are synced from the live `copr-cli list-chroots` output, filtered to chroots whose architecture appears in `packages.json`, then filtered again by excluded distro IDs or distro prefixes from the global `chroot_exclude_distros` list.
- All tracked packages currently target `aarch64` and `x86_64`, excluding `alma-kitten+epel-10-*`, `almalinux-kitten-10-*`, `centos-stream+epel-next-8-*`, `centos-stream-8`, `custom-*`, `epel-7`, `fedora-eln-*`, `mageia-*`, `openeuler-*`, `rhel-7`, and `rhel-8`.
- `gogcli` uses vendored Go modules.
- `wacli` uses vendored Go modules and follows the upstream CGO `sqlite_fts5` build configuration so the local message index keeps FTS5 enabled.
- `codex` uses the upstream Linux musl release artifacts and depends on the Fedora `ripgrep` package instead of bundling `rg`.
- `opencode` uses the upstream Linux release artifacts and packages the `x86_64` baseline build so one RPM works on a wider range of Fedora systems.
- `ollama` uses the upstream Linux release bundles and does not package the separate ROCm or JetPack add-on archives.
- `claude-code` uses the upstream npm tarball and installs the upstream `claude` command name.
- `claude-code` is proprietary software distributed under Anthropic's legal terms rather than an open-source license; review those terms before publishing it in a public COPR.
- `hermes-agent` uses the upstream date-style release tags, but tracks the Python package version from `pyproject.toml`. Its RPM installs source under `/usr/share/hermes-agent`; the installed launcher creates a user-local virtual environment on first run.
- The umbrella `ai` COPR does not rebuild packages; it only points users at the canonical per-package repos through `copr://...` runtime dependencies.
