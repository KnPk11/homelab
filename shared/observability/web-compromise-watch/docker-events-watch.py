#!/usr/bin/env python3
"""Alert on container start: privileged, host network, or host port not in baseline."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

HOST = os.uname().nodename.split(".")[0]
SEND = os.environ.get("TELEGRAM_SEND", "/usr/local/sbin/homelab-watch-send")
BASELINE = Path(os.environ.get("PORTS_BASELINE", "/var/lib/web-compromise-watch/ports.baseline"))


def docker_json(args: list[str]) -> object:
    raw = subprocess.check_output(["docker", *args], text=True)
    return json.loads(raw) if raw.strip() else None


def published_host_ports(inspect: dict) -> list[str]:
    binds = (inspect.get("HostConfig") or {}).get("PortBindings") or {}
    ports: list[str] = []
    for maps in binds.values():
        if not maps:
            continue
        for mapping in maps:
            hp = (mapping or {}).get("HostPort") or ""
            if hp:
                ports.append(hp)
    return ports


def snapshot_ports() -> set[str]:
    ids = subprocess.check_output(["docker", "ps", "-q"], text=True).split()
    ports: set[str] = set()
    for cid in ids:
        data = docker_json(["inspect", cid])
        if not data:
            continue
        ports.update(published_host_ports(data[0]))
    return ports


def load_baseline() -> set[str]:
    BASELINE.parent.mkdir(parents=True, exist_ok=True)
    if not BASELINE.exists() or BASELINE.stat().st_size == 0:
        ports = snapshot_ports()
        BASELINE.write_text("\n".join(sorted(ports, key=lambda p: (len(p), p))) + ("\n" if ports else ""))
        print(f"docker-events-watch: wrote initial port baseline ({len(ports)} ports)", flush=True)
        return ports
    return {line.strip() for line in BASELINE.read_text().splitlines() if line.strip()}


def notify(text: str) -> None:
    print(text, flush=True)
    subprocess.run([SEND, text], check=False)


def handle_start(cid: str, known: set[str]) -> None:
    data = docker_json(["inspect", cid])
    if not data:
        return
    info = data[0]
    name = (info.get("Name") or "").lstrip("/")
    hc = info.get("HostConfig") or {}
    flags: list[str] = []
    if hc.get("Privileged"):
        flags.append("privileged=true")
    if (hc.get("NetworkMode") or "") == "host":
        flags.append("network=host")
    for port in published_host_ports(info):
        if port not in known:
            flags.append(f"new-port={port}")
    if flags:
        notify(f"web-compromise {HOST}: docker start {name} {' '.join(flags)}")


def main() -> int:
    known = load_baseline()
    proc = subprocess.Popen(
        [
            "docker",
            "events",
            "--filter",
            "type=container",
            "--filter",
            "event=start",
            "--format",
            "{{json .}}",
        ],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
            cid = ev.get("id") or (ev.get("Actor") or {}).get("ID") or ""
            if cid:
                handle_start(cid, known)
        except Exception as exc:  # noqa: BLE001 — keep the watcher alive
            print(f"docker-events-watch: {exc}", file=sys.stderr, flush=True)
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
