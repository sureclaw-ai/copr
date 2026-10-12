#!/usr/bin/env python3
"""Resubmit COPR builds whose latest build failed for a transient reason.

The nightly workflow only triggers a COPR build when a package's spec or its
upstream version changes.  A build that fails for a *transient* reason -- a
scarce builder timing out during backend finalisation, an expired distribution
GPG key on the builder, a flaky mirror -- therefore stays red until the next
version bump, and any per-chroot RPM it failed to produce stays missing from
the repository.

This step closes that gap.  It inspects each package's most recent COPR build
and resubmits the ones whose latest build ``failed``, bounded to a small number
of attempts per version so a *genuinely* broken package is not resubmitted for
ever (after the cap it is left red for a human to look at).

The build state is read from the public COPR REST API (no authentication).
Resubmission uses ``copr-cli`` and therefore needs the usual COPR credentials.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import urllib.request

API_ROOT = "https://copr.fedorainfracloud.org/api_3"

# COPR build states that are still in flight -- a build is already queued or
# running, so there is nothing to resubmit.
IN_FLIGHT_STATES = frozenset(
    {"running", "pending", "starting", "importing", "waiting"}
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True, help="COPR owner (project group)")
    parser.add_argument(
        "--packages-json",
        default="packages.json",
        type=pathlib.Path,
        help="Path to packages.json",
    )
    parser.add_argument(
        "--package",
        action="append",
        default=[],
        help="Limit to these package names (repeatable); default is all",
    )
    parser.add_argument(
        "--max-attempts",
        type=int,
        default=3,
        help=(
            "Stop auto-resubmitting once this many builds of the current "
            "version have failed (default: 3)"
        ),
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="How many recent builds to inspect per package (default: 50)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be resubmitted without calling copr-cli",
    )
    return parser.parse_args()


def fetch_builds(owner: str, project: str, limit: int) -> list[dict]:
    """Return the project's builds, newest first."""
    url = (
        f"{API_ROOT}/build/list/?ownername={owner}"
        f"&projectname={project}&limit={limit}"
    )
    with urllib.request.urlopen(url, timeout=60) as response:
        payload = json.load(response)
    builds = payload.get("items", [])
    builds.sort(key=lambda build: build["id"], reverse=True)
    return builds


def version_of(build: dict) -> str | None:
    source = build.get("source_package") or {}
    return source.get("version")


def resubmit(owner: str, project: str, name: str) -> None:
    subprocess.run(
        [
            "copr-cli",
            "build-package",
            f"{owner}/{project}",
            "--name",
            name,
            "--background",
            "--nowait",
        ],
        check=True,
    )


def main() -> int:
    args = parse_args()
    config = json.loads(args.packages_json.read_text(encoding="utf-8"))
    packages = config["packages"]
    if args.package:
        wanted = set(args.package)
        packages = [pkg for pkg in packages if pkg["name"] in wanted]
        missing = wanted - {pkg["name"] for pkg in packages}
        if missing:
            print(f"Unknown package(s): {', '.join(sorted(missing))}", file=sys.stderr)
            return 2

    resubmitted: list[str] = []
    exhausted: list[str] = []
    failures = 0

    for pkg in packages:
        name = pkg["name"]
        project = pkg["project"]
        try:
            builds = fetch_builds(args.owner, project, args.limit)
        except Exception as error:  # noqa: BLE001 - report and continue
            print(f"{name}: could not query COPR: {error}", file=sys.stderr)
            failures += 1
            continue

        if not builds:
            print(f"{name}: no builds found; skipping")
            continue

        latest = builds[0]
        state = latest.get("state")
        version = version_of(latest)

        if state in IN_FLIGHT_STATES:
            print(f"{name}: latest build #{latest['id']} is {state}; skipping")
            continue
        if state != "failed":
            print(f"{name}: latest build #{latest['id']} is {state}; OK")
            continue

        # Bound retries: count how many builds of this same version have failed.
        failed_same_version = sum(
            1
            for build in builds
            if version_of(build) == version and build.get("state") == "failed"
        )
        if failed_same_version >= args.max_attempts:
            print(
                f"{name}: {failed_same_version} failed builds at {version} "
                f"(>= {args.max_attempts}); leaving red for a human"
            )
            exhausted.append(name)
            continue

        action = "would resubmit" if args.dry_run else "resubmitting"
        print(
            f"{name}: latest build #{latest['id']} ({version}) failed "
            f"[attempt {failed_same_version + 1}/{args.max_attempts}]; {action}"
        )
        if args.dry_run:
            resubmitted.append(name)
            continue
        try:
            resubmit(args.owner, project, name)
            resubmitted.append(name)
        except subprocess.CalledProcessError as error:
            print(f"{name}: copr-cli resubmit failed: {error}", file=sys.stderr)
            failures += 1

    print(
        f"\nSummary: {len(resubmitted)} resubmitted, "
        f"{len(exhausted)} exhausted, {failures} errors"
    )
    if resubmitted:
        print("  resubmitted: " + ", ".join(resubmitted))
    if exhausted:
        print("  needs attention: " + ", ".join(exhausted))

    # Exhausted packages and query/resubmit errors are worth surfacing, but must
    # not fail the nightly workflow -- a resubmit is best-effort self-healing.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
