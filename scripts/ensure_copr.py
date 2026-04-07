#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys

FEDORA_CHROOT_RE = re.compile(r"^fedora-(\d+|rawhide)-(x86_64|aarch64)$")


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
    parser.add_argument("--package", required=True)
    parser.add_argument("--clone-url", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--timeout", type=int, default=7200)
    parser.add_argument("--max-builds", type=int, default=10)
    return parser.parse_args()


def project_ref(owner: str, project: str) -> str:
    return f"{owner}/{project}"


def list_fedora_chroots() -> list[str]:
    result = run(["copr-cli", "list-chroots"])
    chroots = []
    for line in result.stdout.splitlines():
        candidate = line.strip()
        if FEDORA_CHROOT_RE.fullmatch(candidate):
            chroots.append(candidate)
    if not chroots:
        raise RuntimeError("no Fedora x86_64/aarch64 chroots were returned by copr-cli")
    return sorted(chroots, key=chroot_sort_key)


def chroot_sort_key(chroot: str) -> tuple[int, str]:
    version, arch = chroot.split("-")[1], chroot.split("-")[2]
    if version == "rawhide":
        return (10_000, arch)
    return (int(version), arch)


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


def ensure_project(ref: str, chroots: list[str]) -> None:
    description = "Automatic COPR packaging for steipete/gogcli."
    instructions = f"dnf copr enable {ref}\ndnf install gogcli"
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
        ".",
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
    chroots = list_fedora_chroots()
    ensure_project(ref, chroots)
    ensure_package(args, ref)
    print(f"synced {ref} for {args.package} across {len(chroots)} Fedora chroots")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover
        print(str(exc), file=sys.stderr)
        sys.exit(1)
