#!/usr/bin/env python3
"""Query the public Copr API for sureclaw's build status and logs.

No authentication required: sureclaw's projects are public, so the REST API
and log files are openly served. stdlib only (urllib + gzip), no deps.

Subcommands:
  failures [project]   Latest build per project; flag any that failed/running.
  chroots <build_id>   List every chroot of a build, grouped by state.
  logs <build_id> [chroot] [--log build|builder-live|root] [--full]
                       Print a build chroot's log. With no chroot, picks the
                       first failed chroot. Default shows the tail; --full dumps
                       everything. --log selects which log (default builder-live).

Examples:
  ./copr.py failures
  ./copr.py failures gogcli
  ./copr.py chroots 10563104
  ./copr.py logs 10563104
  ./copr.py logs 10563104 fedora-44-x86_64 --log build --full
"""
from __future__ import annotations

import gzip
import json
import sys
import urllib.request
from pathlib import Path

OWNER = "sureclaw"
API = "https://copr.fedorainfracloud.org/api_3"
TAIL_LINES = 120


def projects() -> list[tuple[str, str]]:
    """(package_name, project_name) pairs, read from packages.json if findable."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        pj = parent / "packages.json"
        if pj.is_file():
            data = json.loads(pj.read_text())
            return [(p["name"], p["project"]) for p in data["packages"]]
    # Fallback if run outside the repo.
    names = ["gogcli", "wacli", "codex", "opencode", "ollama",
             "claude-code", "nodejs25-caged"]
    return [(n, n) for n in names]


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def latest_build(project: str) -> dict | None:
    url = f"{API}/build/list/?ownername={OWNER}&projectname={project}&limit=20"
    items = get_json(url).get("items", [])
    if not items:
        return None
    return max(items, key=lambda b: b["id"])


def build_chroots(build_id: int) -> list[dict]:
    url = f"{API}/build-chroot/list?build_id={build_id}"
    return get_json(url).get("items", [])


def cmd_failures(args: list[str]) -> int:
    targets = projects()
    if args:
        targets = [(n, p) for (n, p) in targets if p == args[0] or n == args[0]]
        if not targets:
            print(f"No such project: {args[0]}", file=sys.stderr)
            return 2
    any_bad = False
    for name, project in targets:
        b = latest_build(project)
        if b is None:
            print(f"  ?  {project:18} (no builds)")
            continue
        state = b["state"]
        ver = b.get("source_package", {}).get("version", "?")
        mark = {"succeeded": "OK ", "failed": "!! ", "running": ".. ",
                "pending": ".. ", "importing": ".. "}.get(state, "?? ")
        if state not in ("succeeded",):
            any_bad = True
        line = f"  {mark} {project:18} #{b['id']} {state:10} {ver}"
        if state == "failed":
            failed = [c["name"] for c in build_chroots(b["id"])
                      if c["state"] == "failed"]
            line += f"  ({len(failed)} chroot(s) failed)"
        print(line)
    if not any_bad:
        print("\nAll latest builds succeeded.")
    else:
        print("\nDrill in:  ./copr.py chroots <build_id>   then   "
              "./copr.py logs <build_id> [chroot]")
    return 0


def cmd_chroots(args: list[str]) -> int:
    if not args:
        print("usage: chroots <build_id>", file=sys.stderr)
        return 2
    build_id = int(args[0])
    chroots = build_chroots(build_id)
    if not chroots:
        print(f"No chroots for build {build_id} (wrong id, or not started).")
        return 0
    by_state: dict[str, list[str]] = {}
    for c in chroots:
        by_state.setdefault(c["state"], []).append(c["name"])
    print(f"Build #{build_id}: {len(chroots)} chroots")
    for state in sorted(by_state, key=lambda s: (s != "failed", s)):
        names = sorted(by_state[state])
        print(f"\n  {state} ({len(names)}):")
        for n in names:
            print(f"    {n}")
    return 0


def fetch_log(result_url: str, which: str) -> str:
    url = f"{result_url}{which}.log.gz"
    with urllib.request.urlopen(url, timeout=60) as r:
        return gzip.decompress(r.read()).decode("utf-8", "replace")


def cmd_logs(args: list[str]) -> int:
    which = "builder-live"
    full = False
    pos: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--full":
            full = True
        elif a == "--log":
            i += 1
            which = args[i]
        else:
            pos.append(a)
        i += 1
    if not pos:
        print("usage: logs <build_id> [chroot] [--log build|builder-live|root] "
              "[--full]", file=sys.stderr)
        return 2
    build_id = int(pos[0])
    want_chroot = pos[1] if len(pos) > 1 else None
    chroots = build_chroots(build_id)
    if not chroots:
        print(f"No chroots for build {build_id}.", file=sys.stderr)
        return 1
    if want_chroot:
        chosen = next((c for c in chroots if c["name"] == want_chroot), None)
        if chosen is None:
            print(f"No chroot {want_chroot!r} in build {build_id}. Have: "
                  + ", ".join(c["name"] for c in chroots), file=sys.stderr)
            return 1
    else:
        chosen = next((c for c in chroots if c["state"] == "failed"), None)
        if chosen is None:
            print(f"No failed chroot in build {build_id} (states: "
                  + ", ".join(sorted({c['state'] for c in chroots}))
                  + "). Pass a chroot name explicitly.", file=sys.stderr)
            return 1
        print(f"# auto-selected first failed chroot: {chosen['name']}\n")
    text = fetch_log(chosen["result_url"], which)
    print(f"# {chosen['name']} [{chosen['state']}] {which}.log")
    print(f"# {chosen['result_url']}{which}.log.gz\n")
    lines = text.splitlines()
    if not full and len(lines) > TAIL_LINES:
        print(f"# ... showing last {TAIL_LINES} of {len(lines)} lines "
              f"(--full for all) ...\n")
        lines = lines[-TAIL_LINES:]
    print("\n".join(lines))
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 0
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "failures":
        return cmd_failures(rest)
    if cmd == "chroots":
        return cmd_chroots(rest)
    if cmd == "logs":
        return cmd_logs(rest)
    print(f"Unknown command: {cmd}\n", file=sys.stderr)
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
