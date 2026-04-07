# gogcli COPR packaging

This repository packages [`steipete/gogcli`](https://github.com/steipete/gogcli) for Fedora COPR.

The source RPM is generated in COPR's SCM build phase via `.copr/Makefile`, which vendors Go modules before the actual RPM build runs. That keeps the RPM build offline while avoiding committed source tarballs in this repo.

## What is included

- `gogcli.spec`: the RPM spec tracked in git
- `.copr/Makefile`: COPR SCM entrypoint for `make_srpm`
- `scripts/make_srpm.sh`: clones the upstream tag, vendors modules, and emits the SRPM
- `scripts/ensure_copr.py`: creates or updates the COPR project and package source definition
- `.github/workflows/update-copr.yml`: weekly upstream check plus optional manual rebuild

## GitHub configuration

Add these repository variables:

- `COPR_OWNER`: COPR owner, for example `yourname` or `@your-group`
- `COPR_PROJECT`: COPR project name
- `COPR_URL` (optional): defaults to `https://copr.fedorainfracloud.org`

Add these repository secrets:

- `COPR_LOGIN`
- `COPR_USERNAME`
- `COPR_TOKEN`

The workflow runs every Monday at `00:15` UTC and can also be started manually. Use the manual run with `force_build=true` for the first bootstrap build or to rebuild the currently packaged version.

## How the workflow behaves

1. Checks the latest upstream `v*` tag from `https://github.com/steipete/gogcli.git`.
2. Updates `gogcli.spec` when the upstream version changes and pushes that commit back to this repository.
3. Ensures the COPR project exists, enables all currently available Fedora `x86_64` and `aarch64` chroots, and turns on `follow-fedora-branching`.
4. Ensures the COPR package source points at this repository and uses the `make_srpm` method.
5. Starts a COPR build when a new upstream version was found, or when the manual workflow is run with `force_build=true`.

## Notes

- The COPR project chroots are synced from the live `copr-cli list-chroots` output, filtered to `fedora-*-(x86_64|aarch64)`.
- The spec is constrained to `ExclusiveArch: aarch64 x86_64`.
- The build uses vendored Go modules and does not depend on upstream release artifacts.

