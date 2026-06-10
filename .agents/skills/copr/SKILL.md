---
name: copr
description: >-
  Query the Copr build farm for this project's packages — without the user
  pasting anything. Owner `sureclaw`'s projects are PUBLIC, so the REST API and
  build logs need NO authentication. Use when asked "did anything fail on
  copr?", "which chroots failed?", "show me the build log", "what's the latest
  build of <package>", or any question about Copr build status/logs.
---

# Copr build status & logs

The Copr projects built by this repo live under owner **`sureclaw`** and are
**public**. That means the REST API (`https://copr.fedorainfracloud.org/api_3`)
and the log files
(`https://download.copr.fedorainfracloud.org/results/sureclaw/...`) are openly
served — **no token, no login, nothing for the user to paste.** Just curl them.

The packages (project names): `gogcli`, `wacli`, `codex`, `opencode`, `ollama`,
`claude-code`, `nodejs25-caged`, plus the umbrella meta-project `ai`. The
authoritative list is `packages.json` at the repo root (`.packages[].project`).

`copr-cli` is installed but **unconfigured and unnecessary** for reading — it's
only needed for private projects or to *trigger/manage* builds (which CI does
via secrets). For everything below, the API is enough.

## Use the helper

`./copr.py` (next to this file, stdlib-only Python, no deps) wraps the three top
operations. Run it from anywhere; it finds `packages.json` by walking up.

### 1. Has anything failed?
```
.claude/skills/copr/copr.py failures            # all packages
.claude/skills/copr/copr.py failures gogcli      # one package
```
Reports the **latest** build per project with state and version, and counts
failed chroots. A build's top-level state is `failed` iff one or more chroots
failed, so this is the at-a-glance health check.

### 2. Which chroots (for a given build)?
```
.claude/skills/copr/copr.py chroots <build_id>
```
Lists every chroot grouped by state (`failed` first). Get the `<build_id>` from
the `failures` output (e.g. `#10563104`).

### 3. Logs for the failed chroot
```
.claude/skills/copr/copr.py logs <build_id>                       # auto-picks first failed chroot, builder-live.log tail
.claude/skills/copr/copr.py logs <build_id> <chroot>             # specific chroot
.claude/skills/copr/copr.py logs <build_id> <chroot> --log build  # build.log instead
.claude/skills/copr/copr.py logs <build_id> <chroot> --full       # whole log, not just tail
```
Logs available per chroot: `builder-live` (full mock console — start here for
failures), `build` (rpmbuild output), `root` (dnf/mock setup). The script prints
the source URL so you can hand it to the user.

Typical flow: `failures` → spot a `!!` → `chroots <id>` to see the spread →
`logs <id>` to read why. Failures are usually identical across chroots, so the
auto-selected one is representative; check a second chroot only if states differ.

## Raw API (if the helper can't express what you need)

```
# Latest builds for a project (sort by id desc for newest):
curl -s "https://copr.fedorainfracloud.org/api_3/build/list/?ownername=sureclaw&projectname=<project>&limit=20"

# Per-chroot states + result_url for a build (note: HYPHEN, no trailing slash form):
curl -s "https://copr.fedorainfracloud.org/api_3/build-chroot/list?build_id=<id>"

# A chroot's log (result_url from above + filename):
curl -s "<result_url>builder-live.log.gz" | gunzip
```

Notes / gotchas:
- The chroot endpoint is `build-chroot/list` (hyphen). `build/chroot/list`
  returns "Such API endpoint doesn't exist".
- `build/list` items are **not** ordered; sort by `id` descending for the latest.
- Log files are gzipped (`.log.gz`); pipe through `gunzip`.
- Owner/project config originates from the `update-copr.yml` workflow's GitHub
  Actions vars (`COPR_OWNER=sureclaw`), not from repo files.
