#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import subprocess
import sys

VERSION_LINE_RE = re.compile(r"^(Version:\s+)(\S+)(\s*)$")
TAG_RE = re.compile(r"refs/tags/v(\d+\.\d+\.\d+)$")
CHANGELOG_MARKER = "%changelog"
CHANGELOG_AUTHOR = "Codex Automation <noreply@users.noreply.github.com>"


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def read_spec_version(spec_path: pathlib.Path) -> str:
    for line in spec_path.read_text(encoding="utf-8").splitlines():
        match = VERSION_LINE_RE.match(line)
        if match:
            return match.group(2)
    raise RuntimeError(f"could not find Version line in {spec_path}")


def latest_upstream_version(upstream_url: str) -> str:
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", upstream_url],
        check=True,
        text=True,
        capture_output=True,
    )
    versions = []
    for line in result.stdout.splitlines():
        _, ref = line.split("\t", 1)
        match = TAG_RE.search(ref)
        if match:
            versions.append(match.group(1))
    if not versions:
        raise RuntimeError(f"no semver tags found in {upstream_url}")
    return max(versions, key=version_key)


def update_spec(spec_path: pathlib.Path, new_version: str) -> bool:
    lines = spec_path.read_text(encoding="utf-8").splitlines()
    updated = []
    replaced_version = False
    for line in lines:
        match = VERSION_LINE_RE.match(line)
        if match:
            current_version = match.group(2)
            if current_version == new_version:
                return False
            updated.append(f"{match.group(1)}{new_version}{match.group(3)}")
            replaced_version = True
            continue
        updated.append(line)

    if not replaced_version:
        raise RuntimeError(f"could not update Version line in {spec_path}")

    try:
        changelog_index = updated.index(CHANGELOG_MARKER)
    except ValueError as exc:
        raise RuntimeError(f"missing {CHANGELOG_MARKER} in {spec_path}") from exc

    date_text = dt.datetime.now(dt.timezone.utc).strftime("%a %b %d %Y")
    entry = [
        f"* {date_text} {CHANGELOG_AUTHOR} - {new_version}-1",
        f"- Update to v{new_version}",
        "",
    ]
    updated = updated[: changelog_index + 1] + entry + updated[changelog_index + 1 :]
    spec_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
    return True


def write_github_output(output_path: pathlib.Path, values: dict[str, str]) -> None:
    with output_path.open("a", encoding="utf-8") as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=pathlib.Path)
    parser.add_argument("--upstream-url", required=True)
    parser.add_argument("--update", action="store_true")
    parser.add_argument("--github-output", type=pathlib.Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    current_version = read_spec_version(args.spec)
    latest_version = latest_upstream_version(args.upstream_url)
    changed = version_key(latest_version) > version_key(current_version)

    if args.update and changed:
        changed = update_spec(args.spec, latest_version)

    outputs = {
        "current_version": current_version,
        "latest_version": latest_version,
        "changed": str(changed).lower(),
    }
    if args.github_output:
        write_github_output(args.github_output, outputs)

    for key, value in outputs.items():
        print(f"{key}={value}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

