#!/usr/bin/env python3
"""Triage a batch of instances for the two known host-level failure modes.

    ./triage-hosts.py [name-substring]

Both signals come from `openstack console log show`, so no SSH is needed and
instances that accept TCP but never complete an SSH handshake are still
classifiable.

    DEAD-EGRESS   No "running" marker well past the ~30s a healthy boot takes.
                  The instance usually reports {"status":"error"} itself with a
                  "no outbound network" reason, but not always.

    WEDGED        The system-load-logging heartbeat has gone stale. That cron
                  job runs every minute and needs no network, so a stopped
                  heartbeat means userspace is blocked rather than waiting.
                  Observed with a hanging CephFS /software automount, which
                  blocks anything touching /software -- including Lmod's
                  profile scripts, so sshd accepts the connection and then
                  stalls before the banner. This mode reports NOTHING on its
                  own; without the heartbeat check it is indistinguishable from
                  "still working".

Anything not OK is not worth waiting on: delete it and launch another.

Two things this deliberately gets right, having got them wrong first:

  * Instance names may contain spaces (Exosphere names a batch "foo 1 of 10"),
    so the server list is read as JSON rather than split on whitespace.
  * Ages are measured against the newest epoch observed across the batch, not
    against the local clock. The two differ by minutes, which previously
    produced negative ages and false DEAD-EGRESS verdicts.
"""
import json
import re
import subprocess
import sys

# Seconds from "starting" to "running" before we call an instance dead.
#
# Deliberately generous. A quiet boot reaches "running" in ~30-50s, but ten
# simultaneous launches contending for the same hosts produced legitimate
# completions at +497s, +574s, +578s, +579s and +587s. An earlier 120s budget
# condemned all of those as DEAD-EGRESS while they were merely slow, which is
# the worse error: this tool exists to decide what to delete.
#
# Fast detection does not depend on this anyway -- a genuinely dead instance
# usually self-reports {"status":"error"} within a couple of minutes, and the
# heartbeat check below catches the silent wedge. This budget is only the
# backstop for an instance that does neither.
RUNNING_BUDGET = 600
HEARTBEAT_BUDGET = 150  # seconds of heartbeat silence before we call it wedged

ANSI = re.compile(r"\x1b\[[0-9;]*m")
MARKER = re.compile(r'\{"status":"([a-z]+)", "epoch": (\d+)')
HEARTBEAT = re.compile(r'\{"epoch": (\d+), "cpuPctUsed')
SKIP_STATES = {"DELETED", "SHELVED", "SHELVED_OFFLOADED"}


def sh(*args):
    r = subprocess.run(args, capture_output=True, text=True)
    return ANSI.sub("", r.stdout)


def collect(pattern):
    try:
        servers = json.loads(sh("openstack", "server", "list", "-f", "json") or "[]")
    except json.JSONDecodeError:
        sys.exit("could not list servers -- is an openrc sourced?")

    rows, clock = [], 0
    for s in servers:
        name, status = s.get("Name", "?"), s.get("Status", "?")
        if status in SKIP_STATES or (pattern and pattern not in name):
            continue

        log = sh("openstack", "console", "log", "show", s["ID"])
        # epochs in the status markers are milliseconds; heartbeats are seconds
        marks = {k: int(v) // 1000 for k, v in MARKER.findall(log)}
        last = MARKER.findall(log)
        last_status = last[-1][0] if last else None
        beats = [int(m) for m in HEARTBEAT.findall(log)]
        hb = beats[-1] if beats else None

        clock = max([clock, hb or 0, *marks.values()])
        rows.append((name, status, last_status, marks, hb))
    return rows, clock


def verdict(last_status, marks, hb, clock):
    start, run = marks.get("starting"), marks.get("running")

    if last_status == "complete":
        return "OK"
    if last_status == "error":
        return "DEAD-EGRESS (self-reported)"
    if hb is not None and clock - hb > HEARTBEAT_BUDGET:
        return "WEDGED (heartbeat stale)"
    if start is None:
        # A long-running instance's console has scrolled past the boot markers.
        # Absence of evidence is not evidence of failure -- say nothing.
        return "-- (no boot markers in console)"
    if run is None and clock - start > RUNNING_BUDGET:
        return "DEAD-EGRESS (no 'running')"
    return "pending"


def main():
    pattern = sys.argv[1] if len(sys.argv) > 1 else None
    rows, clock = collect(pattern)
    if not rows:
        print("no instances matched")
        return

    print(f"{'NAME':<24} {'STATUS':<8} {'CONSOLE':<22} {'HEARTBEAT':<10} VERDICT")
    for name, status, last_status, marks, hb in rows:
        start, run = marks.get("starting"), marks.get("running")
        if start and run:
            console = f"{last_status} (+{run - start}s)"
        elif start:
            console = f"{last_status} ({clock - start}s ago)"
        else:
            console = last_status or "none"
        age = f"{clock - hb}s" if hb is not None else "-"
        print(
            f"{name:<24} {status:<8} {console:<22} {age:<10} "
            f"{verdict(last_status, marks, hb, clock)}"
        )


if __name__ == "__main__":
    main()
