#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse
import urllib.request

VERSION_LINE_RE = re.compile(r"^(Version:\s+)(\S+)(\s*)$")
RELEASE_LINE_RE = re.compile(r"^(Release:\s+)(\S+)(\s*)$")
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


def latest_upstream_version(upstream_url: str, tag_prefix: str) -> str:
    tag_re = re.compile(rf"refs/tags/{re.escape(tag_prefix)}(\d+\.\d+\.\d+)$")
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", upstream_url],
        check=True,
        text=True,
        capture_output=True,
    )
    versions = []
    for line in result.stdout.splitlines():
        _, ref = line.split("\t", 1)
        match = tag_re.search(ref)
        if match:
            versions.append(match.group(1))
    if not versions:
        raise RuntimeError(f"no semver tags found in {upstream_url} with prefix {tag_prefix!r}")
    return max(versions, key=version_key)


def latest_npm_version(package_name: str) -> str:
    registry_url = "https://registry.npmjs.org/" + urllib.parse.quote(package_name, safe="")
    with urllib.request.urlopen(registry_url) as response:
        metadata = json.load(response)
    try:
        return metadata["dist-tags"]["latest"]
    except KeyError as exc:
        raise RuntimeError(f"could not determine latest npm dist-tag for {package_name}") from exc


def update_spec(spec_path: pathlib.Path, new_version: str) -> bool:
    lines = spec_path.read_text(encoding="utf-8").splitlines()
    updated = []
    replaced_version = False
    reset_release = False
    for line in lines:
        match = VERSION_LINE_RE.match(line)
        if match:
            current_version = match.group(2)
            if current_version == new_version:
                return False
            updated.append(f"{match.group(1)}{new_version}{match.group(3)}")
            replaced_version = True
            reset_release = True
            continue
        match = RELEASE_LINE_RE.match(line)
        if match and reset_release:
            updated.append(f"{match.group(1)}1%{{?dist}}{match.group(3)}")
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
    parser.add_argument("--upstream-url")
    parser.add_argument("--npm-package")
    parser.add_argument("--tag-prefix", default="v")
    parser.add_argument("--update", action="store_true")
    parser.add_argument("--github-output", type=pathlib.Path)
    args = parser.parse_args()
    if bool(args.upstream_url) == bool(args.npm_package):
        parser.error("provide exactly one of --upstream-url or --npm-package")
    return args


def main() -> int:
    args = parse_args()
    current_version = read_spec_version(args.spec)
    if args.npm_package:
        latest_version = latest_npm_version(args.npm_package)
    else:
        latest_version = latest_upstream_version(args.upstream_url, args.tag_prefix)
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
