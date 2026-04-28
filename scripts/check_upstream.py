#!/usr/bin/env python3

from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import json
import pathlib
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
import tomllib

VERSION_LINE_RE = re.compile(r"^(Version:\s+)(\S+)(\s*)$")
RELEASE_LINE_RE = re.compile(r"^(Release:\s+)(\S+)(\s*)$")
CHANGELOG_MARKER = "%changelog"
CHANGELOG_AUTHOR = "Codex Automation <noreply@users.noreply.github.com>"
DEFAULT_GIT_TIMEOUT = 60
DEFAULT_HTTP_TIMEOUT = 30
DEFAULT_JOBS = 8


@dataclass(frozen=True)
class PackageCheck:
    name: str
    spec: pathlib.Path
    upstream_url: str | None = None
    npm_package: str | None = None
    tag_prefix: str = "v"
    tag_version_pattern: str = r"(\d+\.\d+\.\d+)"
    version_source: str = "tag"


@dataclass(frozen=True)
class PackageResult:
    name: str
    current_version: str
    latest_version: str
    changed: bool


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def github_raw_url(upstream_url: str, tag: str, path: str) -> str:
    repo_path = upstream_url.removeprefix("https://github.com/").removesuffix(".git")
    if repo_path == upstream_url:
        raise RuntimeError(f"unsupported upstream URL for raw fetch: {upstream_url}")
    return f"https://raw.githubusercontent.com/{repo_path}/{urllib.parse.quote(tag, safe='')}/{path}"


def read_spec_version(spec_path: pathlib.Path) -> str:
    for line in spec_path.read_text(encoding="utf-8").splitlines():
        match = VERSION_LINE_RE.match(line)
        if match:
            return match.group(2)
    raise RuntimeError(f"could not find Version line in {spec_path}")


async def git_ls_remote(upstream_url: str, *, timeout: int = DEFAULT_GIT_TIMEOUT) -> str:
    process = await asyncio.create_subprocess_exec(
        "git",
        "ls-remote",
        "--tags",
        "--refs",
        upstream_url,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        process.kill()
        await process.communicate()
        raise RuntimeError(f"git ls-remote timed out for {upstream_url}") from None
    if process.returncode != 0:
        details = stderr.decode().strip() or stdout.decode().strip()
        raise RuntimeError(f"git ls-remote failed for {upstream_url}: {details}")
    return stdout.decode()


async def latest_upstream_tag(upstream_url: str, tag_prefix: str, tag_version_pattern: str) -> tuple[str, str]:
    tag_re = re.compile(rf"refs/tags/({re.escape(tag_prefix)}{tag_version_pattern})$")
    output = await git_ls_remote(upstream_url)
    versions: list[tuple[str, str]] = []
    for line in output.splitlines():
        _, ref = line.split("\t", 1)
        match = tag_re.search(ref)
        if match:
            versions.append((match.group(1), match.group(2)))
    if not versions:
        raise RuntimeError(f"no matching tags found in {upstream_url} with prefix {tag_prefix!r}")
    return max(versions, key=lambda item: version_key(item[1]))


async def latest_pyproject_version(upstream_url: str, tag: str) -> str:
    def fetch() -> str:
        request = urllib.request.Request(
            github_raw_url(upstream_url, tag, "pyproject.toml"),
            headers={"User-Agent": "gogcli-copr-check-upstream/1.0"},
        )
        with urllib.request.urlopen(request, timeout=DEFAULT_HTTP_TIMEOUT) as response:
            pyproject = tomllib.loads(response.read().decode("utf-8"))
        try:
            return pyproject["project"]["version"]
        except KeyError as exc:
            raise RuntimeError(f"could not determine project.version for {upstream_url} at {tag}") from exc

    return await asyncio.to_thread(fetch)


async def latest_upstream_version(
    upstream_url: str,
    tag_prefix: str,
    tag_version_pattern: str,
    version_source: str,
) -> str:
    tag, tag_version = await latest_upstream_tag(upstream_url, tag_prefix, tag_version_pattern)
    if version_source == "tag":
        return tag_version
    if version_source == "pyproject":
        return await latest_pyproject_version(upstream_url, tag)
    raise RuntimeError(f"unsupported version source: {version_source}")


def fetch_npm_metadata(package_name: str, *, timeout: int = DEFAULT_HTTP_TIMEOUT) -> dict:
    registry_url = "https://registry.npmjs.org/" + urllib.parse.quote(package_name, safe="")
    request = urllib.request.Request(
        registry_url,
        headers={"User-Agent": "gogcli-copr-check-upstream/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


async def latest_npm_version(package_name: str) -> str:
    metadata = await asyncio.to_thread(fetch_npm_metadata, package_name)
    try:
        return metadata["dist-tags"]["latest"]
    except KeyError as exc:
        raise RuntimeError(f"could not determine latest npm dist-tag for {package_name}") from exc


async def latest_version_for_package(package: PackageCheck) -> str:
    if package.npm_package:
        return await latest_npm_version(package.npm_package)
    if package.upstream_url:
        return await latest_upstream_version(
            package.upstream_url,
            package.tag_prefix,
            package.tag_version_pattern,
            package.version_source,
        )
    raise RuntimeError(f"package {package.name} is missing an upstream source")


async def latest_versions_for_packages(
    packages: list[PackageCheck],
    *,
    jobs: int = DEFAULT_JOBS,
) -> dict[str, str]:
    semaphore = asyncio.Semaphore(max(1, jobs))

    async def fetch(package: PackageCheck) -> tuple[str, str]:
        async with semaphore:
            return package.name, await latest_version_for_package(package)

    pairs = await asyncio.gather(*(fetch(package) for package in packages))
    return dict(pairs)


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


def load_packages(packages_json: pathlib.Path) -> list[PackageCheck]:
    raw = json.loads(packages_json.read_text(encoding="utf-8"))
    base_dir = packages_json.parent
    packages = []
    for item in raw["packages"]:
        spec_path = base_dir / item["subdir"] / item["spec"]
        package = PackageCheck(
            name=item["name"],
            spec=spec_path,
            upstream_url=item.get("upstream_url"),
            npm_package=item.get("npm_package"),
            tag_prefix=item.get("tag_prefix", "v"),
            tag_version_pattern=item.get("tag_version_pattern", r"(\d+\.\d+\.\d+)"),
            version_source=item.get("version_source", "tag"),
        )
        if bool(package.upstream_url) == bool(package.npm_package):
            raise RuntimeError(
                f"package {package.name} must define exactly one of upstream_url or npm_package",
            )
        packages.append(package)
    return packages


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=pathlib.Path)
    parser.add_argument("--packages-json", type=pathlib.Path)
    parser.add_argument("--upstream-url")
    parser.add_argument("--npm-package")
    parser.add_argument("--tag-prefix", default="v")
    parser.add_argument("--tag-version-pattern", default=r"(\d+\.\d+\.\d+)")
    parser.add_argument("--version-source", choices=("tag", "pyproject"), default="tag")
    parser.add_argument("--update", action="store_true")
    parser.add_argument("--github-output", type=pathlib.Path)
    parser.add_argument("--jobs", type=int, default=DEFAULT_JOBS)
    args = parser.parse_args()

    if bool(args.spec) == bool(args.packages_json):
        parser.error("provide exactly one of --spec or --packages-json")

    if args.spec:
        if bool(args.upstream_url) == bool(args.npm_package):
            parser.error("provide exactly one of --upstream-url or --npm-package")
    else:
        disallowed = [
            args.upstream_url,
            args.npm_package,
            args.tag_prefix != "v",
            args.tag_version_pattern != r"(\d+\.\d+\.\d+)",
            args.version_source != "tag",
        ]
        if any(disallowed):
            parser.error("source selection arguments are only valid with --spec")

    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    return args


async def check_packages(packages: list[PackageCheck], *, update: bool, jobs: int) -> list[PackageResult]:
    latest_versions = await latest_versions_for_packages(packages, jobs=jobs)
    results = []
    for package in packages:
        current_version = read_spec_version(package.spec)
        latest_version = latest_versions[package.name]
        changed = version_key(latest_version) > version_key(current_version)
        if update and changed:
            changed = update_spec(package.spec, latest_version)
        results.append(
            PackageResult(
                name=package.name,
                current_version=current_version,
                latest_version=latest_version,
                changed=changed,
            )
        )
    return results


def print_single_result(result: PackageResult) -> None:
    outputs = {
        "current_version": result.current_version,
        "latest_version": result.latest_version,
        "changed": str(result.changed).lower(),
    }
    for key, value in outputs.items():
        print(f"{key}={value}")


def print_batch_results(results: list[PackageResult]) -> None:
    for result in results:
        print(
            f"{result.name}: current_version={result.current_version} "
            f"latest_version={result.latest_version} changed={str(result.changed).lower()}"
        )
    changed_packages = [result.name for result in results if result.changed]
    print(f"changed_any={str(bool(changed_packages)).lower()}")
    print(f"changed_packages={','.join(changed_packages)}")


def main() -> int:
    args = parse_args()
    if args.spec:
        packages = [
            PackageCheck(
                name=args.spec.stem,
                spec=args.spec,
                upstream_url=args.upstream_url,
                npm_package=args.npm_package,
                tag_prefix=args.tag_prefix,
                tag_version_pattern=args.tag_version_pattern,
                version_source=args.version_source,
            )
        ]
    else:
        packages = load_packages(args.packages_json)

    results = asyncio.run(check_packages(packages, update=args.update, jobs=args.jobs))

    if args.spec:
        result = results[0]
        if args.github_output:
            write_github_output(
                args.github_output,
                {
                    "current_version": result.current_version,
                    "latest_version": result.latest_version,
                    "changed": str(result.changed).lower(),
                },
            )
        print_single_result(result)
        return 0

    changed_packages = [result.name for result in results if result.changed]
    if args.github_output:
        write_github_output(
            args.github_output,
            {
                "changed_any": str(bool(changed_packages)).lower(),
                "changed_packages": ",".join(changed_packages),
            },
        )
    print_batch_results(results)
    return 0


if __name__ == "__main__":
    sys.exit(main())
