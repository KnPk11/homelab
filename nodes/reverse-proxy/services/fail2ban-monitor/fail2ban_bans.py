#!/usr/bin/env python3
"""
Fail2Ban & CrowdSec Intrusion Monitor
=============================================================================
Version 5.0
Date: 2026-08-29

HTTP widget of bans in a rolling 24h window.

CrowdSec `cscli alerts list` defaults to 50 rows, and Fail2Ban/CrowdSec logs
are truncated nightly by process_logs.sh. Neither is a reliable 24h source.
This process appends each observed ban to a JSONL history file and serves
only that file, filtered to the last 24 hours.

Usage:
  python3 fail2ban_bans.py
  python3 fail2ban_bans.py --record --ip 1.2.3.4 --jail sshd --source F2B
  python3 fail2ban_bans.py --ingest-once
  # systemd: fail2ban-monitor.service -> /srv/fail2ban-monitor/fail2ban_bans.py
"""
from __future__ import annotations

import argparse
import fcntl
import glob
import gzip
import html
import json
import os
import re
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

# --- CONFIGURATION ---
PORT = 9002
HISTORY_FILE = "/srv/fail2ban-monitor/banned-history.jsonl"
WINDOW = timedelta(hours=24)
HISTORY_KEEP = timedelta(hours=48)
INGEST_INTERVAL_SEC = 30
SOURCE_RANK = {"F2B": 0, "CS": 1}  # lower = preferred / listed first
LOCAL_TZ = datetime.now().astimezone().tzinfo

F2B_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),.*?"
    r"\[([^\]]+)\]\s+"
    r"(?:Increase Ban|Ban)\s+"
    r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
)

_ingest_lock = threading.Lock()
_file_lock = threading.Lock()
_last_ingest = 0.0
_last_prune = 0.0


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def parse_cs_timestamp(raw: str) -> datetime | None:
    if not raw:
        return None
    text = raw.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        try:
            dt = datetime.strptime(text.split(".")[0], "%Y-%m-%dT%H:%M:%S")
            dt = dt.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def parse_f2b_timestamp(raw: str) -> datetime | None:
    try:
        dt = datetime.strptime(raw, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None
    return dt.replace(tzinfo=LOCAL_TZ).astimezone(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def event_key(event: dict) -> str:
    return f"{event.get('source')}|{event.get('ip')}|{event.get('jail')}|{str(event.get('ts', ''))[:19]}"


def open_log(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="ignore")
    return open(path, "r", encoding="utf-8", errors="ignore")


def ensure_history_file() -> None:
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    if not os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, "a", encoding="utf-8"):
            pass


@contextmanager
def locked_history(mode: str):
    """Serialize threads in-process and other writers (Fail2Ban --record) via flock."""
    ensure_history_file()
    with _file_lock:
        with open(HISTORY_FILE, mode, encoding="utf-8") as fh:
            fcntl.flock(fh, fcntl.LOCK_EX)
            try:
                yield fh
            finally:
                try:
                    fcntl.flock(fh, fcntl.LOCK_UN)
                except OSError:
                    pass


def append_new_events(events: list[dict]) -> int:
    if not events:
        return 0
    added = 0
    with locked_history("a+") as fh:
        fh.seek(0)
        existing = set()
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                existing.add(event_key(json.loads(line)))
            except json.JSONDecodeError:
                continue
        for event in events:
            key = event_key(event)
            if key in existing:
                continue
            fh.write(json.dumps(event, separators=(",", ":")) + "\n")
            existing.add(key)
            added += 1
        fh.flush()
        os.fsync(fh.fileno())
    return added


def prune_history(now: datetime | None = None) -> None:
    global _last_prune
    if not os.path.exists(HISTORY_FILE):
        return
    now = now or utcnow()
    if now.timestamp() - _last_prune < 3600:
        return
    cutoff = now - HISTORY_KEEP
    with locked_history("r+") as fh:
        kept = []
        dropped = False
        for line in fh:
            raw = line.strip()
            if not raw:
                continue
            try:
                item = json.loads(raw)
                dt = parse_cs_timestamp(item.get("ts", ""))
            except json.JSONDecodeError:
                dropped = True
                continue
            if dt is None or dt >= cutoff:
                kept.append(raw + "\n")
            else:
                dropped = True
        if dropped:
            fh.seek(0)
            fh.truncate()
            fh.writelines(kept)
            fh.flush()
            os.fsync(fh.fileno())
    _last_prune = now.timestamp()


def load_events_since(since: datetime) -> list[dict]:
    events = []
    if not os.path.exists(HISTORY_FILE):
        return events
    with locked_history("r") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            dt = parse_cs_timestamp(item.get("ts", ""))
            ip = item.get("ip")
            jail = item.get("jail") or ""
            source = item.get("source") or "CS"
            if dt is None or ip is None or dt < since:
                continue
            events.append(
                {
                    "dt": dt,
                    "ip": ip,
                    "jail": jail,
                    "source": source,
                    "color": "#c0392b" if source == "F2B" else "#e67e22",
                }
            )
    return events


def classify_cs_alert(item: dict) -> dict | None:
    ip = (item.get("source") or {}).get("ip") or (item.get("source") or {}).get("value")
    scenario = item.get("scenario") or ""
    created_at = item.get("created_at") or item.get("start_at")
    dt = parse_cs_timestamp(created_at or "")
    if not ip or not scenario or dt is None:
        return None
    source = "CS"
    jail = scenario
    if "Fail2Ban" in scenario:
        source = "F2B"
        jail = scenario.replace("Fail2Ban: ", "").replace("Fail2Ban ban: ", "")
    return {"ts": iso(dt), "ip": ip, "jail": jail, "source": source}


def fetch_crowdsec_alerts(since: str) -> list[dict]:
    try:
        result = subprocess.check_output(
            ["cscli", "alerts", "list", "-o", "json", "--since", since, "--limit", "0"],
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"Error reading CS CLI: {exc}", file=sys.stderr)
        return []
    if not result or not result.strip():
        return []
    try:
        data = json.loads(result)
    except json.JSONDecodeError as exc:
        print(f"Error parsing CS CLI JSON: {exc}", file=sys.stderr)
        return []
    if not data:
        return []
    events = []
    for item in data:
        event = classify_cs_alert(item)
        if event:
            events.append(event)
    return events


def fail2ban_log_paths(backfill: bool) -> list[str]:
    paths = list(glob.glob("/var/log/fail2ban.log*"))
    if backfill:
        paths.extend(glob.glob("/mnt/logs/current/fail2ban/fail2ban.log"))
        paths.extend(glob.glob("/mnt/logs/archive/fail2ban/fail2ban-*.gz"))
    # Unique, keep order
    seen = set()
    ordered = []
    for path in paths:
        if path not in seen and os.path.exists(path):
            seen.add(path)
            ordered.append(path)
    return ordered


def fetch_fail2ban_log_events(backfill: bool) -> list[dict]:
    cutoff = utcnow() - (HISTORY_KEEP if backfill else timedelta(hours=2))
    events = []
    for log_file in fail2ban_log_paths(backfill):
        try:
            with open_log(log_file) as fh:
                for line in fh:
                    match = F2B_PATTERN.search(line)
                    if not match:
                        continue
                    ts_str, jail, ip = match.groups()
                    dt = parse_f2b_timestamp(ts_str)
                    if dt is None or dt < cutoff:
                        continue
                    events.append(
                        {"ts": iso(dt), "ip": ip, "jail": jail, "source": "F2B"}
                    )
        except OSError as exc:
            print(f"Error reading F2B log {log_file}: {exc}", file=sys.stderr)
    return events


def ingest_sources(backfill: bool = False) -> int:
    since = "48h" if backfill else "20m"
    events = fetch_crowdsec_alerts(since)
    events.extend(fetch_fail2ban_log_events(backfill=backfill))
    added = append_new_events(events)
    prune_history()
    if added:
        print(f"Ingested {added} new ban event(s) into {HISTORY_FILE}", flush=True)
    return added


def ingest_if_stale(min_interval: float, backfill: bool = False) -> None:
    global _last_ingest
    with _ingest_lock:
        now = time.time()
        if not backfill and now - _last_ingest < min_interval:
            return
        ingest_sources(backfill=backfill)
        _last_ingest = time.time()


def ingest_loop() -> None:
    while True:
        try:
            ingest_if_stale(min_interval=0)
        except Exception as exc:
            print(f"Ingest loop error: {exc}", file=sys.stderr)
        time.sleep(INGEST_INTERVAL_SEC)


def record_ban(ip: str, jail: str, source: str) -> None:
    event = {
        "ts": iso(utcnow()),
        "ip": ip,
        "jail": jail,
        "source": source if source in SOURCE_RANK else "F2B",
    }
    append_new_events([event])


def prefer_f2b(events: list[dict]) -> list[dict]:
    """
    One row per IP. Prefer Fail2Ban over CrowdSec when both reported a ban;
    among the same source, keep the newest event.
    """
    ordered = sorted(events, key=lambda e: e["dt"], reverse=True)
    by_ip = {}
    for event in ordered:
        ip = event["ip"]
        existing = by_ip.get(ip)
        if existing is None:
            by_ip[ip] = event
            continue
        if SOURCE_RANK.get(event["source"], 99) < SOURCE_RANK.get(existing["source"], 99):
            by_ip[ip] = event
    return list(by_ip.values())


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        try:
            ingest_if_stale(min_interval=10)
        except Exception as exc:
            print(f"Request ingest error: {exc}", file=sys.stderr)

        cutoff = utcnow() - WINDOW
        events = prefer_f2b(load_events_since(cutoff))
        events.sort(key=lambda e: e["dt"], reverse=True)

        rows = []
        if not events:
            rows.append(
                "<tr><td colspan='4' style='text-align:center; padding:20px;'>"
                "No bans found in the last 24h</td></tr>"
            )
        else:
            for e in events:
                local_ts = e["dt"].astimezone(LOCAL_TZ).strftime("%Y-%m-%d %H:%M:%S")
                rows.append(
                    f"<tr><td>{html.escape(local_ts)}</td>"
                    f"<td>{html.escape(e['ip'])}</td>"
                    f"<td><span class='badge {html.escape(e['source'])}'>{html.escape(e['source'])}</span> "
                    f"{html.escape(e['jail'])}</td>"
                    f"<td style='color:{html.escape(e['color'])}; font-weight:bold;'>Banned</td></tr>"
                )

        tz_name = datetime.now(LOCAL_TZ).tzname() or "local"
        caption = (
            f"Rolling 24h · {len(events)} IP{'s' if len(events) != 1 else ''} · times {tz_name}"
        )
        self.wfile.write(self.get_html(caption, "".join(rows)).encode("utf-8"))

    def get_html(self, caption: str, table_rows: str) -> str:
        css = """
        body { font-family: monospace; padding: 1rem; background: #121212; color: #eee; font-size: 11px; }
        .caption { margin: 0 0 8px 0; color: #aaa; }
        table { border-collapse: collapse; width: 100%; max-width: 800px; font-size: 11px; }
        th, td { border: 1px solid #444; padding: 8px; text-align: left; }
        th { background-color: #333; }
        tr:nth-child(even) { background-color: #1e1e1e; }
        .badge { padding: 2px 5px; border-radius: 3px; font-size: 9px; font-weight: bold; margin-right: 5px; color: #fff; }
        .F2B { background-color: #c0392b; }
        .CS  { background-color: #e67e22; }
        """
        return f"""
        <html>
          <head>
            <meta http-equiv="refresh" content="60">
            <style>{css}</style>
            <title>Intrusion Monitor</title>
          </head>
          <body>
            <p class="caption">{html.escape(caption)}</p>
            <table>
              <thead><tr><th>Timestamp</th><th>IP Address</th><th>Jail / Scenario</th><th>Status</th></tr></thead>
              <tbody>{table_rows}</tbody>
            </table>
          </body>
        </html>
        """

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))


def run() -> None:
    print(f"Backfilling ban history into {HISTORY_FILE}", flush=True)
    ingest_if_stale(min_interval=0, backfill=True)
    thread = threading.Thread(target=ingest_loop, daemon=True, name="ban-ingest")
    thread.start()
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Serving at http://0.0.0.0:{PORT}", flush=True)
    server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="Fail2Ban & CrowdSec intrusion monitor")
    parser.add_argument("--record", action="store_true", help="Append one ban event and exit")
    parser.add_argument("--ip", help="IP for --record")
    parser.add_argument("--jail", default="", help="Jail/scenario for --record")
    parser.add_argument("--source", default="F2B", help="F2B or CS (default F2B)")
    parser.add_argument("--ingest-once", action="store_true", help="Ingest sources into the history file and exit")
    args = parser.parse_args()

    if args.record:
        if not args.ip:
            print("--record requires --ip", file=sys.stderr)
            sys.exit(2)
        record_ban(args.ip, args.jail, args.source)
        return
    if args.ingest_once:
        ingest_if_stale(min_interval=0, backfill=True)
        return
    run()


if __name__ == "__main__":
    main()
