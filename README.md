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
| `composio` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/composio/package/composio/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/composio/package/composio/) |
| `nodejs-latest` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/nodejs-latest/package/nodejs-latest/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/nodejs-latest/package/nodejs-latest/) |
| `nodejs-lts` | [![Copr build status](https://copr.fedorainfracloud.org/coprs/sureclaw/nodejs-lts/package/nodejs-lts/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/sureclaw/nodejs-lts/package/nodejs-lts/) |

## Packages

- `gogcli`: source-built from upstream git tags with vendored Go modules
- `wacli`: source-built from upstream git tags with vendored Go modules, with CGO enabled and the upstream `sqlite_fts5` build tag
- `codex`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`, with runtime dependencies on `bubblewrap` and `ripgrep`
- `opencode`: repackaged from upstream Linux release binaries for `x86_64` and `aarch64`
- `ollama`: repackaged from upstream Linux release bundles for `x86_64` and `aarch64`
- `claude-code`: repackaged from Anthropic's native release feed (the upstream Bun single-file `claude` binary, checksum-verified against the release manifest) for `x86_64` and `aarch64`; RPM binary post-processing is disabled so the executable ships byte-for-byte
- `composio`: repackaged from upstream `@composio/cli@*` GitHub release zips for `x86_64` and `aarch64`; the whole release tree is installed under `/usr/lib/composio` with a `/usr/bin/composio` symlink, and RPM binary post-processing is disabled so the Bun launcher ships byte-for-byte
- `nodejs-latest`: tracks the newest stable Node.js Current release across major versions and repackages the official `x86_64` and `aarch64` Linux distributions, including `node`, `npm`, `npx`, headers and documentation
- `nodejs-lts`: tracks the newest Node.js LTS release across major versions and packages the same complete official distribution
- `ai`: umbrella COPR project that enables the canonical package COPRs together

## What is included

- `packages/<name>/`: per-package spec and `.copr/Makefile`
- `packages.json`: package list used by the updater workflow
- `pyproject.toml` and `uv.lock`: pinned Python tooling for the GitHub workflow
- `scripts/make_srpm.sh`: clones an upstream git tag, vendors Go modules, and emits an SRPM
- `scripts/make_binary_release_srpm.sh`: downloads release artifacts and emits an SRPM
- `scripts/make_node_binary_srpm.sh`: downloads both official Node.js Linux architectures, verifies them against the upstream SHA-256 manifest, and emits an SRPM
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

1. Checks the latest upstream `v*` tag from `https://github.com/openclaw/gogcli.git`.
2. Checks the latest upstream `v*` tag from `https://github.com/openclaw/wacli.git`.
3. Checks the latest upstream `rust-v*` tag from `https://github.com/openai/codex.git`.
4. Checks the latest upstream `v*` tag from `https://github.com/anomalyco/opencode.git`.
5. Checks the latest upstream `v*` tag from `https://github.com/ollama/ollama.git`.
6. Checks the latest npm `latest` dist-tag for `@anthropic-ai/claude-code`.
7. Checks the official Node.js distribution index for the newest stable Current and LTS releases that publish both supported Linux architectures.
8. Uses `uv` to install the pinned Python toolchain and workflow dependencies from `uv.lock`.
9. Checks all tracked upstream sources concurrently, updates any package spec whose upstream version changed, and pushes that commit back to this repository.
10. Ensures each canonical package COPR project exists, enables all currently available COPR chroots for that package's configured architectures except excluded distros, and turns on `follow-fedora-branching`.
11. Ensures every package source points at this repository and uses the `make_srpm` method from its package subdirectory.
12. Ensures the umbrella COPR project `ai` exists and carries runtime dependencies on the canonical package COPRs.
13. Starts COPR builds only for canonical package projects whose versions changed, or for all canonical package projects when the manual workflow is run with `force_build=true`.

## Notes

- The COPR project chroots are synced from the live `copr-cli list-chroots` output, filtered to chroots whose architecture appears in `packages.json`, then filtered again by excluded distro IDs or distro prefixes from the global `chroot_exclude_distros` list.
- All tracked packages currently target `aarch64` and `x86_64`, excluding `alma-kitten+epel-10-*`, `almalinux-kitten-10-*`, `centos-stream+epel-next-8-*`, `centos-stream-8`, `custom-*`, `epel-7`, `fedora-eln-*`, `mageia-*`, `openeuler-*`, `opensuse-leap-16.0-*`, `opensuse-tumbleweed-*`, `rhel-7`, and `rhel-8`.
- `opensuse-leap-16.0` is excluded because its distribution signing key `35A2F86E29B700A4` (openSUSE Project Signing Key `<opensuse@opensuse.org>`) expired on 2026-06-19, so the buildroot's `openSUSE-build-key` package fails mock's GPG check (`Error: GPG check FAILED`) and every build on that chroot fails regardless of the package. This is an upstream/COPR buildroot issue that cannot be fixed from this repository; remove the exclusion once openSUSE re-signs the key and COPR's `distribution-gpg-keys` is refreshed.
- `gogcli` uses vendored Go modules.
- `wacli` uses vendored Go modules and follows the upstream CGO `sqlite_fts5` build configuration so the local message index keeps FTS5 enabled.
- `codex` uses the upstream Linux musl release artifacts and depends on the Fedora `bubblewrap` and `ripgrep` packages instead of bundling `rg`.
- `opencode` uses the upstream Linux release artifacts and packages the `x86_64` baseline build so one RPM works on a wider range of Fedora systems.
- `ollama` uses the upstream Linux release bundles and does not package the separate ROCm or JetPack add-on archives.
- `claude-code` uses the upstream npm tarball and installs the upstream `claude` command name.
- `composio` tracks the latest stable `@composio/cli@X.Y.Z` GitHub release tag (the `tag` version source skips the `-beta` prereleases that the `releases/latest` endpoint and other monorepo packages would otherwise surface). The upstream release zip bundles the codex ACP helper binary for every platform; the spec keeps only the one matching the build arch (the CLI selects it by `process.platform`/`process.arch` at runtime) and drops the rest, roughly halving the installed size. It is still a large package (a few hundred MB per arch).
- `nodejs-latest` and `nodejs-lts` each own the normal `/usr/bin/node`, `/usr/bin/npm`, `/usr/bin/npx`, headers and bundled npm tree. They cannot be installed together or alongside distro Node.js/npm packages that own those paths.
- The official Node.js Linux binaries require glibc 2.28 or newer and, from Node.js 25 onward, the `libatomic` runtime. The Node packages therefore exclude openSUSE Leap in addition to the repository-wide legacy distro exclusions.
- `claude-code` is proprietary software distributed under Anthropic's legal terms rather than an open-source license; review those terms before publishing it in a public COPR.
- The umbrella `ai` COPR does not rebuild packages; it only points users at the canonical per-package repos through `copr://...` runtime dependencies.
