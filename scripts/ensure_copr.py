#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys

DEFAULT_ARCHES = ("aarch64", "x86_64")
CHROOT_RE = re.compile(r"^(.+)-([a-z0-9_]+)$")


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, check=False, text=True, capture_output=True)
    if check and result.returncode != 0:
        if result.stdout:
            print(result.stdout, file=sys.stderr, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
        raise subprocess.CalledProcessError(result.returncode, command)
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--description")
    parser.add_argument("--instructions")
    parser.add_argument("--runtime-dependency-project", action="append", default=[])
    parser.add_argument("--arch", action="append", default=[])
    parser.add_argument("--exclude-distro", action="append", default=[])
    parser.add_argument("--package")
    parser.add_argument("--clone-url")
    parser.add_argument("--commit")
    parser.add_argument("--subdir", default=".")
    parser.add_argument("--spec")
    parser.add_argument("--timeout", type=int, default=7200)
    parser.add_argument("--max-builds", type=int, default=10)
    args = parser.parse_args()
    package_fields = [args.clone_url, args.commit, args.spec]
    if args.package and not all(package_fields):
        parser.error("--package requires --clone-url, --commit, and --spec")
    if not args.package and any(package_fields):
        parser.error("--clone-url, --commit, and --spec require --package")
    return args


def project_ref(owner: str, project: str) -> str:
    return f"{owner}/{project}"


def effective_arches(arches: list[str]) -> list[str]:
    selected = arches or list(DEFAULT_ARCHES)
    return sorted(set(selected))


def list_chroots(arches: list[str], excluded_distros: list[str]) -> list[str]:
    selected_arches = set(effective_arches(arches))
    excluded_distro_set = set(excluded_distros)
    result = run(["copr-cli", "list-chroots"])
    chroots = []
    for line in result.stdout.splitlines():
        candidate = line.strip()
        match = CHROOT_RE.fullmatch(candidate)
        if not match:
            continue
        distro, arch = match.groups()
        if arch not in selected_arches or distro in excluded_distro_set:
            continue
        chroots.append(candidate)
    if not chroots:
        arches_text = ", ".join(sorted(selected_arches))
        if excluded_distro_set:
            excluded_text = ", ".join(sorted(excluded_distro_set))
            raise RuntimeError(
                "no chroots were returned by copr-cli for arches: "
                f"{arches_text} after excluding distros: {excluded_text}"
            )
        raise RuntimeError(f"no chroots were returned by copr-cli for arches: {arches_text}")
    return sorted(set(chroots))


def project_exists(ref: str) -> bool:
    return run(["copr-cli", "get", ref], check=False).returncode == 0


def package_exists(ref: str, package: str) -> bool:
    return (
        run(
            ["copr-cli", "get-package", ref, "--name", package, "--output-format", "json"],
            check=False,
        ).returncode
        == 0
    )


def runtime_dependency_refs(owner: str, projects: list[str]) -> list[str]:
    return [f"copr://{owner}/{project}" for project in projects]


def ensure_project(args: argparse.Namespace, ref: str, chroots: list[str]) -> None:
    description = args.description or "Automatic COPR packaging for tracked upstream CLI tools."
    instructions = args.instructions or f"dnf copr enable {ref}\ndnf install <package-name>"
    runtime_dependencies = runtime_dependency_refs(args.owner, args.runtime_dependency_project) if args.runtime_dependency_project else []
    base_command = [
        "copr-cli",
        "modify" if project_exists(ref) else "create",
        ref,
        "--description",
        description,
        "--instructions",
        instructions,
        "--follow-fedora-branching",
        "on",
    ]
    for runtime_dependency in runtime_dependencies:
        base_command.extend(["--runtime-repo-dependency", runtime_dependency])
    for chroot in chroots:
        base_command.extend(["--chroot", chroot])
    run(base_command)


def ensure_package(args: argparse.Namespace, ref: str) -> None:
    command_name = "edit-package-scm" if package_exists(ref, args.package) else "add-package-scm"
    command = [
        "copr-cli",
        command_name,
        ref,
        "--name",
        args.package,
        "--clone-url",
        args.clone_url,
        "--commit",
        args.commit,
        "--subdir",
        args.subdir,
        "--spec",
        args.spec,
        "--method",
        "make_srpm",
        "--webhook-rebuild",
        "off",
        "--max-builds",
        str(args.max_builds),
        "--timeout",
        str(args.timeout),
    ]
    run(command)


def main() -> int:
    args = parse_args()
    ref = project_ref(args.owner, args.project)
    chroots = list_chroots(args.arch, args.exclude_distro)
    ensure_project(args, ref, chroots)
    if args.package:
        ensure_package(args, ref)
        print(f"synced {ref} for {args.package} across {len(chroots)} chroots")
    else:
        print(f"synced project {ref} across {len(chroots)} chroots")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover
        print(str(exc), file=sys.stderr)
        sys.exit(1)
