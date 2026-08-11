#!/usr/bin/env python3
# =============================================================================
# caddy_security_scan.py
# Version: 1.0
# Date: 2026-08-11
#
# Security analytics over Caddy + Fail2Ban + CrowdSec + MikroTik logs
#
# - Caddy: public IPs with status 401 / 403 / 429 (denied / rate-limited)
#   Reads live *.log and rotated *.log.gz under current/ + archive/ trees
# - Fail2Ban: Ban / Unban / Increase Ban lines
# - CrowdSec: "… ban on Ip …" log lines (+ optional live decisions dump)
# - MikroTik: firewall drop_* (esp. drop_ssh) + login failure lines
#   current + archive (plain / .gz streamed; no disk unzip)
# - Geocode EVERY finding IP (accurate world coverage — same approach as UK job)
# - Outputs: findings.json, report.txt, security_map.html
#
# Designed to run with system python3 (no Spark required) so it fits a small
# k8s LXC. Point --logs-root at reverse-proxy /mnt/logs (or a staged copy) to
# auto-include current + archive for Caddy / MikroTik / F2B / CrowdSec.
# =============================================================================
from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# Fail2Ban: 2026-08-10 07:11:57,712 fail2ban.actions [pid]: NOTICE  [jail] Ban 1.2.3.4
F2B_BAN_RE = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+\s+"
    r"fail2ban\.(?:actions|observer)\s+\[[^\]]+\]:\s+NOTICE\s+"
    r"\[(?P<jail>[^\]]+)\]\s+"
    r"(?P<action>Ban|Unban|Increase Ban)\s+(?P<ip>\S+)"
)

# CrowdSec: ... : 4h ban on Ip 1.2.3.4
CS_BAN_RE = re.compile(
    r"ban on Ip (?P<ip>\d{1,3}(?:\.\d{1,3}){3})",
    re.IGNORECASE,
)
# CrowdSec: Ip 1.2.3.4 performed 'crowdsecurity/http-probing'
CS_PERF_RE = re.compile(
    r"Ip (?P<ip>\d{1,3}(?:\.\d{1,3}){3}) performed '(?P<reason>[^']+)'",
    re.IGNORECASE,
)
# CrowdSec country hint: (US/398705)
CS_COUNTRY_HINT = re.compile(r"\(([A-Z]{2})/\d+\)")

# MikroTik syslog-style:
# 2026-07-13T00:07:49... 192.168.50.1 firewall,info drop_ssh input: ... 195.178.110.42:51000->86.x:22
MT_TS_RE = re.compile(r"^(?P<ts>\d{4}-\d{2}-\d{2}T[^\s]+)")
MT_DROP_RULE_RE = re.compile(r"firewall,info\s+(?P<rule>drop_[A-Za-z0-9_-]+)", re.IGNORECASE)
MT_CONN_RE = re.compile(
    r"(?P<src>\d{1,3}(?:\.\d{1,3}){3}):(?P<sport>\d+)->"
    r"(?P<dst>\d{1,3}(?:\.\d{1,3}){3}):(?P<dport>\d+)"
)
MT_LOGIN_FAIL_RE = re.compile(
    r"login failure for user (?P<user>\S+) from (?P<ip>\S+) via (?P<via>\S+)",
    re.IGNORECASE,
)

DENIED_STATUSES = {401, 403, 429}
LOG_GLOBS = ("**/*.log", "**/*.json", "**/*.jsonl", "**/*.log.gz", "**/*.json.gz", "**/*.gz")


def is_public_ip(ip: str) -> bool:
    if not ip:
        return False
    if ip.startswith(("10.", "127.", "192.168.", "169.254.")):
        return False
    if ip.startswith("172."):
        try:
            second = int(ip.split(".")[1])
            if 16 <= second <= 31:
                return False
        except (IndexError, ValueError):
            pass
    if ip in ("::1",) or ip.startswith(("fc", "fd", "fe80:")):
        return False
    return True


def open_text(path: Path):
    if path.suffix == ".gz" or path.name.endswith(".gz"):
        return gzip.open(path, "rt", errors="ignore")
    return open(path, "rt", errors="ignore")


def iter_files(root: Path, patterns: Tuple[str, ...] = LOG_GLOBS) -> List[Path]:
    out: List[Path] = []
    if not root.exists():
        return out
    if root.is_file():
        return [root]
    for pat in patterns:
        out.extend(root.rglob(pat))
    # de-dupe
    seen = set()
    files = []
    for p in sorted(out):
        if p.is_file() and str(p) not in seen:
            if p.name.endswith((".tar.gz", ".tgz")):
                continue
            # bare *.gz from LOG_GLOBS may pick non-log noise; keep only log-ish names
            if p.suffix == ".gz" and not any(
                p.name.endswith(s) for s in (".log.gz", ".json.gz", ".jsonl.gz")
            ):
                # allow mikrotik-YYYY-….gz style (no .log in name)
                if not re.match(r"^[a-zA-Z].*", p.name):
                    continue
            seen.add(str(p))
            files.append(p)
    return files


def resolve_component_dirs(paths: List[Path], component: str) -> List[Path]:
    """
    Expand CLI paths into concrete log directories.

    Accepts:
      - flat dir of logs (staged current only)
      - reverse-proxy style root with current/<component> and archive/<component>
      - explicit current/ or archive/ path
      - full /mnt/logs root (component auto-resolved)
    """
    found: List[Path] = []
    seen: Set[str] = set()

    def add(p: Path) -> None:
        if p.exists() and str(p) not in seen:
            seen.add(str(p))
            found.append(p)

    for raw in paths:
        p = raw.expanduser()
        if not p.exists():
            print(f"[paths] missing {p}", file=sys.stderr)
            continue
        if p.is_file():
            add(p.parent)
            continue

        cur = p / "current" / component
        arc = p / "archive" / component
        if cur.is_dir() or arc.is_dir():
            if cur.is_dir():
                add(cur)
            if arc.is_dir():
                add(arc)
            continue

        # path is already …/current/caddy or …/archive/mikrotik
        if p.name == component or p.parent.name in ("current", "archive"):
            add(p)
            continue

        # generic dir of staged files
        add(p)

    return found


def parse_caddy_denied(caddy_dirs: List[Path]) -> Dict[str, Dict[str, Any]]:
    """Aggregate public IPs with 401/403/429 from Caddy JSON logs (live + .gz archives)."""
    files: List[Path] = []
    for d in caddy_dirs:
        files.extend(iter_files(d, ("**/*.log", "**/*.json", "**/*.jsonl", "**/*.log.gz", "**/*.json.gz")))
    # de-dupe paths
    files = list({str(p): p for p in files}.values())
    # prefer json subtree if present (skip plaintext combined logs when both exist)
    json_pref = [p for p in files if "/json/" in str(p).replace("\\", "/")]
    if json_pref:
        files = json_pref

    print(f"[caddy] scanning {len(files)} files under {len(caddy_dirs)} dir(s): "
          + ", ".join(str(d) for d in caddy_dirs))
    per_ip: Dict[str, Dict[str, Any]] = {}
    total_denied = 0

    for fp in files:
        try:
            with open_text(fp) as fh:
                for line in fh:
                    line = line.strip()
                    if not line.startswith("{"):
                        continue
                    try:
                        o = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    st = o.get("status")
                    try:
                        st_i = int(st)
                    except (TypeError, ValueError):
                        continue
                    if st_i not in DENIED_STATUSES:
                        continue
                    req = o.get("request") or {}
                    ip = req.get("client_ip") or req.get("remote_ip")
                    if not is_public_ip(ip):
                        continue
                    total_denied += 1
                    rec = per_ip.get(ip)
                    if rec is None:
                        rec = {
                            "ip": ip,
                            "denied_total": 0,
                            "n_401": 0,
                            "n_403": 0,
                            "n_429": 0,
                            "hosts": set(),
                            "paths": Counter(),
                            "first_ts": None,
                            "last_ts": None,
                        }
                        per_ip[ip] = rec
                    rec["denied_total"] += 1
                    rec[f"n_{st_i}"] = rec.get(f"n_{st_i}", 0) + 1
                    host = req.get("host")
                    if host:
                        rec["hosts"].add(host)
                    uri = (req.get("uri") or "")[:200]
                    if uri:
                        rec["paths"][uri] += 1
                    ts = o.get("ts")
                    if isinstance(ts, (int, float)):
                        if rec["first_ts"] is None or ts < rec["first_ts"]:
                            rec["first_ts"] = ts
                        if rec["last_ts"] is None or ts > rec["last_ts"]:
                            rec["last_ts"] = ts
        except OSError as e:
            print(f"[caddy] skip {fp}: {e}", file=sys.stderr)

    print(f"[caddy] denied events={total_denied:,} unique IPs={len(per_ip):,}")
    return per_ip


def parse_mikrotik(mt_dirs: List[Path]) -> Dict[str, Dict[str, Any]]:
    """
    Parse MikroTik syslog exports (current + archive .gz).

    Security-relevant:
      - firewall drop_* rules (esp. drop_ssh) → public source IPs
      - system login failure … from <ip>
    Ignores routine dstnat/forward noise (caddy_https, dhcp, etc.).
    """
    files: List[Path] = []
    for d in mt_dirs:
        files.extend(iter_files(d, ("**/*",)))
    files = [p for p in files if p.is_file() and not p.name.endswith((".tar.gz", ".tgz"))]
    files = list({str(p): p for p in files}.values())
    print(f"[mikrotik] scanning {len(files)} files under {len(mt_dirs)} dir(s): "
          + ", ".join(str(d) for d in mt_dirs))

    per_ip: Dict[str, Dict[str, Any]] = {}
    drop_events = 0
    login_events = 0

    def rec_for(ip: str) -> Dict[str, Any]:
        r = per_ip.get(ip)
        if r is None:
            r = {
                "ip": ip,
                "drop_total": 0,
                "drop_ssh": 0,
                "login_failures": 0,
                "rules": Counter(),
                "users": Counter(),
                "vias": Counter(),
                "first_ts": None,
                "last_ts": None,
            }
            per_ip[ip] = r
        return r

    def touch_ts(r: Dict[str, Any], line: str) -> None:
        m = MT_TS_RE.match(line)
        if not m:
            return
        ts = m.group("ts")
        if r["first_ts"] is None or ts < r["first_ts"]:
            r["first_ts"] = ts
        if r["last_ts"] is None or ts > r["last_ts"]:
            r["last_ts"] = ts

    for fp in files:
        try:
            with open_text(fp) as fh:
                for line in fh:
                    # login failures (any source — LAN failures are still interesting)
                    lm = MT_LOGIN_FAIL_RE.search(line)
                    if lm:
                        ip = lm.group("ip").rstrip(",")
                        # strip trailing punctuation
                        ip = ip.split("%")[0]
                        if re.match(r"^\d{1,3}(?:\.\d{1,3}){3}$", ip) or ":" in ip:
                            r = rec_for(ip)
                            r["login_failures"] += 1
                            r["users"][lm.group("user")] += 1
                            r["vias"][lm.group("via").rstrip(",")] += 1
                            touch_ts(r, line)
                            login_events += 1
                        continue

                    if "firewall,info" not in line:
                        continue
                    # only drop_* rules — not every dstnat
                    dm = MT_DROP_RULE_RE.search(line)
                    if not dm:
                        continue
                    rule = dm.group("rule")
                    cm = MT_CONN_RE.search(line)
                    if not cm:
                        continue
                    ip = cm.group("src")
                    if not is_public_ip(ip):
                        continue
                    r = rec_for(ip)
                    r["drop_total"] += 1
                    r["rules"][rule] += 1
                    if rule.lower() == "drop_ssh" or "ssh" in rule.lower():
                        r["drop_ssh"] += 1
                    touch_ts(r, line)
                    drop_events += 1
        except OSError as e:
            print(f"[mikrotik] skip {fp}: {e}", file=sys.stderr)

    print(
        f"[mikrotik] drop_events={drop_events:,} login_failures={login_events:,} "
        f"unique IPs={len(per_ip):,}"
    )
    return per_ip


def parse_fail2ban(f2b_paths: List[Path]) -> Dict[str, Dict[str, Any]]:
    """Parse Ban/Unban/Increase Ban from fail2ban logs (plain + gz)."""
    per_ip: Dict[str, Dict[str, Any]] = {}
    ban_events = 0
    for fp in f2b_paths:
        try:
            with open_text(fp) as fh:
                for line in fh:
                    m = F2B_BAN_RE.search(line)
                    if not m:
                        continue
                    ip = m.group("ip").rstrip(",")
                    if not is_public_ip(ip):
                        continue
                    action = m.group("action")
                    jail = m.group("jail")
                    ts = m.group("ts")
                    rec = per_ip.get(ip)
                    if rec is None:
                        rec = {
                            "ip": ip,
                            "ban_count": 0,
                            "unban_count": 0,
                            "increase_count": 0,
                            "jails": set(),
                            "last_ban": None,
                            "last_unban": None,
                            "events": [],
                        }
                        per_ip[ip] = rec
                    rec["jails"].add(jail)
                    if action == "Ban":
                        rec["ban_count"] += 1
                        rec["last_ban"] = ts
                        ban_events += 1
                    elif action == "Unban":
                        rec["unban_count"] += 1
                        rec["last_unban"] = ts
                    elif action == "Increase Ban":
                        rec["increase_count"] += 1
                        rec["last_ban"] = ts
                        ban_events += 1
                    rec["events"].append({"ts": ts, "action": action, "jail": jail})
        except OSError as e:
            print(f"[f2b] skip {fp}: {e}", file=sys.stderr)
    print(f"[f2b] ban-related IPs={len(per_ip):,} ban/increase events≈{ban_events:,}")
    return per_ip


def parse_crowdsec(cs_paths: List[Path]) -> Dict[str, Dict[str, Any]]:
    """Parse CrowdSec ban / scenario lines from logs."""
    per_ip: Dict[str, Dict[str, Any]] = {}
    for fp in cs_paths:
        try:
            with open_text(fp) as fh:
                for line in fh:
                    ip = None
                    reason = None
                    m = CS_BAN_RE.search(line)
                    if m:
                        ip = m.group("ip")
                    m2 = CS_PERF_RE.search(line)
                    if m2:
                        ip = m2.group("ip")
                        reason = m2.group("reason")
                    if not ip or not is_public_ip(ip):
                        continue
                    # only keep lines that look like decisions / bans / scenarios
                    if "ban" not in line.lower() and "performed" not in line.lower():
                        continue
                    rec = per_ip.get(ip)
                    if rec is None:
                        rec = {
                            "ip": ip,
                            "ban_count": 0,
                            "reasons": Counter(),
                            "country_hint": None,
                        }
                        per_ip[ip] = rec
                    if "ban on Ip" in line or "ban on Ip" in line.lower():
                        rec["ban_count"] += 1
                    if reason:
                        rec["reasons"][reason] += 1
                    ch = CS_COUNTRY_HINT.search(line)
                    if ch:
                        rec["country_hint"] = ch.group(1)
        except OSError as e:
            print(f"[cs] skip {fp}: {e}", file=sys.stderr)
    print(f"[cs] crowdsec IPs with ban/scenario={len(per_ip):,}")
    return per_ip


def load_cscli_dump(path: Optional[Path]) -> Dict[str, Dict[str, Any]]:
    """Optional CSV/raw from: cscli decisions list -o raw > decisions.csv"""
    if not path or not path.exists():
        return {}
    out: Dict[str, Dict[str, Any]] = {}
    with open(path, "rt", errors="ignore") as fh:
        header = fh.readline()
        for line in fh:
            parts = line.strip().split(",")
            if len(parts) < 5:
                continue
            # id,source,ip,reason,action,country,...
            ip_field = parts[2]
            ip = ip_field.replace("Ip:", "").strip()
            if not is_public_ip(ip):
                continue
            out[ip] = {
                "ip": ip,
                "reason": parts[3] if len(parts) > 3 else "",
                "action": parts[4] if len(parts) > 4 else "",
                "country_hint": parts[5] if len(parts) > 5 else "",
                "active_decision": True,
            }
    print(f"[cscli] active/dumped decisions={len(out):,}")
    return out


def geocode_all(ips: List[str], pause: float = 4.1, cache: Optional[Dict] = None) -> Dict[str, Dict[str, Any]]:
    """Full accurate geocode (same batch approach as UK job)."""
    geo: Dict[str, Dict[str, Any]] = dict(cache or {})
    need = [ip for ip in ips if ip not in geo or not geo[ip].get("lat")]
    print(f"[geo] cache hit {len(ips) - len(need)}, need fetch {len(need)}")
    for i in range(0, len(need), 100):
        batch = need[i : i + 100]
        body = json.dumps(
            [
                {
                    "query": ip,
                    "fields": "status,message,country,countryCode,regionName,city,lat,lon,isp,org,as,query",
                }
                for ip in batch
            ]
        ).encode()
        req = urllib.request.Request(
            "http://ip-api.com/batch",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                rows = json.loads(resp.read().decode())
            for row in rows:
                q = row.get("query")
                if q:
                    geo[q] = row
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"[geo] batch failed: {e}", file=sys.stderr)
        done = min(i + 100, len(need))
        print(f"[geo] {done}/{len(need)}", flush=True)
        if done < len(need):
            time.sleep(pause)
    return geo


def score_finding(
    caddy: Optional[Dict],
    f2b: Optional[Dict],
    cs: Optional[Dict],
    mt: Optional[Dict] = None,
) -> Tuple[str, List[str]]:
    """Return severity + matched rule names."""
    rules = []
    denied = (caddy or {}).get("denied_total") or 0
    n401 = (caddy or {}).get("n_401") or 0
    n403 = (caddy or {}).get("n_403") or 0
    n429 = (caddy or {}).get("n_429") or 0
    bans = (f2b or {}).get("ban_count") or 0
    bans += (f2b or {}).get("increase_count") or 0
    cs_bans = (cs or {}).get("ban_count") or 0
    hosts = len((caddy or {}).get("hosts") or [])
    auth_denied = n401 + n403
    mt_drops = (mt or {}).get("drop_total") or 0
    mt_ssh = (mt or {}).get("drop_ssh") or 0
    mt_login = (mt or {}).get("login_failures") or 0

    if bans >= 1 or cs_bans >= 1:
        rules.append("banned")
    if auth_denied >= 50:
        rules.append("auth_denied_heavy")
    if n429 >= 100:
        rules.append("rate_limited_heavy")
    if denied >= 200:
        rules.append("denied_volume")
    if hosts >= 8 and denied >= 50:
        rules.append("multi_vhost_spray")
    if bans >= 2 or (f2b or {}).get("increase_count", 0) >= 1:
        rules.append("repeat_offender")
    if mt_ssh >= 20 or mt_drops >= 50:
        rules.append("mt_firewall_drop_heavy")
    elif mt_ssh >= 5 or mt_drops >= 10:
        rules.append("mt_firewall_drop")
    if mt_login >= 1:
        rules.append("mt_login_failure")

    if not rules and denied >= 10:
        rules.append("denied_light")
    if not rules and (bans or cs_bans):
        rules.append("banned")
    if not rules and mt_drops >= 5:
        rules.append("mt_firewall_drop")

    if "banned" in rules and (auth_denied >= 50 or denied >= 100):
        sev = "high"
    elif "auth_denied_heavy" in rules or "repeat_offender" in rules or "multi_vhost_spray" in rules:
        sev = "high"
    elif "mt_firewall_drop_heavy" in rules or ("mt_login_failure" in rules and not is_public_ip((mt or {}).get("ip") or "")):
        # LAN login failures are medium; public login failures high if many
        sev = "medium" if mt_login < 3 else "high"
    elif "mt_login_failure" in rules and is_public_ip((mt or {}).get("ip") or ""):
        sev = "high"
    elif "rate_limited_heavy" in rules or "denied_volume" in rules or "mt_firewall_drop_heavy" in rules:
        sev = "medium"
    elif rules:
        sev = "low"
    else:
        sev = "info"
    return sev, rules


def render_security_map(out_path: Path, findings: List[Dict[str, Any]], meta: Dict[str, Any]) -> None:
    points = []
    for f in findings:
        g = f.get("geo") or {}
        if g.get("lat") is None:
            continue
        denied = f.get("denied_total") or 0
        points.append(
            {
                "ip": f["ip"],
                "lat": g["lat"],
                "lon": g["lon"],
                "city": g.get("city") or "",
                "country": g.get("country") or "",
                "cc": g.get("countryCode") or "",
                "isp": g.get("isp") or g.get("org") or "",
                "denied": denied,
                "n401": f.get("n_401") or 0,
                "n403": f.get("n_403") or 0,
                "n429": f.get("n_429") or 0,
                "f2b_bans": f.get("fail2ban_bans") or 0,
                "cs_bans": f.get("crowdsec_bans") or 0,
                "mt_drops": f.get("mt_drop_total") or 0,
                "mt_ssh": f.get("mt_drop_ssh") or 0,
                "mt_login": f.get("mt_login_failures") or 0,
                "severity": f.get("severity") or "info",
                "rules": ", ".join(f.get("rules") or []),
                "jails": ", ".join(f.get("fail2ban_jails") or []),
            }
        )

    by_country = Counter()
    for p in points:
        by_country[p["country"] or "Unknown"] += p["denied"] or p["f2b_bans"] or 1
    countries = sorted([{"country": k, "score": v} for k, v in by_country.items()], key=lambda x: -x["score"])[:30]

    sev_color = {
        "high": "#ff5b6e",
        "medium": "#ffb020",
        "low": "#5b9dff",
        "info": "#8b9bb8",
    }

    top = sorted(findings, key=lambda f: (-(f.get("denied_total") or 0), -(f.get("fail2ban_bans") or 0)))[:40]

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Edge security map — denied & banned</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    :root {{ --bg:#0b1020; --panel:#121a2f; --text:#e8eefc; --muted:#8b9bb8; --accent:#5b9dff; --hot:#ff5b6e; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; font-family:ui-sans-serif,system-ui,sans-serif;
      background:radial-gradient(1100px 520px at 15% -10%, #2a1530 0%, var(--bg) 55%); color:var(--text); }}
    header {{ padding:1.15rem 1.5rem .5rem; border-bottom:1px solid #1e2a48; }}
    header h1 {{ margin:0 0 .25rem; font-size:1.28rem; }}
    header p {{ margin:0; color:var(--muted); font-size:.9rem; }}
    .layout {{ display:grid; grid-template-columns:1.35fr 1fr; gap:1rem; padding:1rem 1.5rem 1.4rem; }}
    @media (max-width:960px) {{ .layout {{ grid-template-columns:1fr; }} }}
    #map {{ height:min(75vh,740px); border-radius:14px; border:1px solid #243356;
      box-shadow:0 10px 40px rgba(0,0,0,.35); }}
    .panel {{ background:var(--panel); border:1px solid #243356; border-radius:14px;
      padding:1rem; max-height:min(75vh,740px); overflow:auto; }}
    .stats {{ display:grid; grid-template-columns:repeat(2,1fr); gap:.55rem; margin-bottom:.85rem; }}
    .stat {{ background:#0e162b; border-radius:10px; padding:.55rem .65rem; border:1px solid #1c2a4a; }}
    .stat .k {{ color:var(--muted); font-size:.7rem; text-transform:uppercase; letter-spacing:.04em; }}
    .stat .v {{ font-size:1.08rem; font-weight:650; margin-top:.1rem; }}
    h2 {{ font-size:.9rem; margin:.85rem 0 .35rem; color:var(--accent); }}
    table {{ width:100%; border-collapse:collapse; font-size:.78rem; }}
    th,td {{ text-align:left; padding:.3rem .25rem; border-bottom:1px solid #1c2a4a; }}
    th {{ color:var(--muted); }}
    .mono {{ font-family:ui-monospace,Menlo,monospace; }}
    .sev-high {{ color:#ff5b6e; font-weight:650; }}
    .sev-medium {{ color:#ffb020; font-weight:650; }}
    .sev-low {{ color:#5b9dff; }}
    footer {{ padding:0 1.5rem 1.1rem; color:var(--muted); font-size:.78rem; }}
    .legend span {{ display:inline-block; width:10px; height:10px; border-radius:50%; margin-right:4px; }}
  </style>
</head>
<body>
  <header>
    <h1>Edge security — denied (401/403/429) & bans</h1>
    <p>
      {meta.get("finding_ips",0):,} IPs ·
      {meta.get("denied_events",0):,} denied hits ·
      {meta.get("fail2ban_ban_ips",0):,} Fail2Ban ·
      {meta.get("crowdsec_ips",0):,} CrowdSec ·
      {len(points):,} mapped · geocoded all findings
    </p>
    <p class="legend" style="margin-top:.4rem">
      <span style="background:#ff5b6e"></span>high
      <span style="background:#ffb020;margin-left:.6rem"></span>medium
      <span style="background:#5b9dff;margin-left:.6rem"></span>low
    </p>
  </header>
  <div class="layout">
    <div id="map"></div>
    <aside class="panel">
      <div class="stats">
        <div class="stat"><div class="k">Finding IPs</div><div class="v">{meta.get("finding_ips",0):,}</div></div>
        <div class="stat"><div class="k">Denied events</div><div class="v">{meta.get("denied_events",0):,}</div></div>
        <div class="stat"><div class="k">Fail2Ban IPs</div><div class="v">{meta.get("fail2ban_ban_ips",0):,}</div></div>
        <div class="stat"><div class="k">CrowdSec IPs</div><div class="v">{meta.get("crowdsec_ips",0):,}</div></div>
      </div>
      <h2>Top countries (denied volume among findings)</h2>
      <table>
        <tr><th>Country</th><th>Score</th></tr>
        {"".join(f"<tr><td>{c['country']}</td><td class='mono'>{c['score']:,}</td></tr>" for c in countries)}
      </table>
      <h2>Top offenders</h2>
      <table>
        <tr><th>Sev</th><th>IP</th><th>Denied</th><th>Ban</th><th>Where</th></tr>
        {"".join(
          f"<tr><td class='sev-{f.get('severity','info')}'>{f.get('severity')}</td>"
          f"<td class='mono'>{f['ip']}</td>"
          f"<td class='mono'>{f.get('denied_total') or 0}</td>"
          f"<td class='mono'>{(f.get('fail2ban_bans') or 0)+(f.get('crowdsec_bans') or 0)}</td>"
          f"<td>{((f.get('geo') or {}).get('country') or '—')[:16]}</td></tr>"
          for f in top
        )}
      </table>
    </aside>
  </div>
  <footer>
    Caddy 401/403/429 + Fail2Ban Ban lines + CrowdSec ban logs · full geocode of finding IPs (not top-N of all traffic)
  </footer>
  <script>
    const points = {json.dumps(points)};
    const sevColor = {json.dumps(sev_color)};
    const map = L.map('map').setView([20,0], 2);
    L.tileLayer('https://{{s}}.basemaps.cartocdn.com/dark_all/{{z}}/{{x}}/{{y}}{{r}}.png', {{
      attribution: '&copy; OSM &copy; CARTO', maxZoom: 18
    }}).addTo(map);
    function radiusFor(p) {{
      const v = (p.denied || 0) + 10*(p.f2b_bans||0) + 10*(p.cs_bans||0) + (p.mt_drops||0) + 5*(p.mt_login||0);
      return Math.max(2, Math.min(6, 1.5 + Math.log10(v+1)*1.2));
    }}
    const layer = L.layerGroup().addTo(map);
    points.forEach(p => {{
      const col = sevColor[p.severity] || '#8b9bb8';
      L.circleMarker([p.lat,p.lon], {{
        radius: radiusFor(p), color: col, fillColor: col, fillOpacity: 0.82, weight: 0.6
      }}).bindPopup(
        `<div style="min-width:210px">
          <b class="mono">${{p.ip}}</b> · <span style="color:${{col}}">${{p.severity}}</span><br/>
          ${{p.city ? p.city+', ' : ''}}${{p.country}} <small>${{p.cc}}</small><br/>
          <small>${{p.isp}}</small><br/>
          denied: <b>${{p.denied}}</b> (401=${{p.n401}} 403=${{p.n403}} 429=${{p.n429}})<br/>
          fail2ban bans: <b>${{p.f2b_bans}}</b> · crowdsec: <b>${{p.cs_bans}}</b><br/>
          mikrotik drops: <b>${{p.mt_drops}}</b> (ssh=${{p.mt_ssh}}) · login fail: <b>${{p.mt_login}}</b><br/>
          jails: ${{p.jails || '—'}}<br/>
          rules: ${{p.rules || '—'}}
        </div>`
      ).addTo(layer);
    }});
    if (points.length) map.fitBounds(layer.getBounds().pad(0.2));
  </script>
</body>
</html>
"""
    out_path.write_text(html, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Caddy + Fail2Ban + CrowdSec + MikroTik security map"
    )
    ap.add_argument(
        "--logs-root",
        default="",
        help="Reverse-proxy style root (e.g. /mnt/logs or staged copy) with "
        "current/{caddy,fail2ban,crowdsec,mikrotik} and archive/… — expands all components",
    )
    ap.add_argument(
        "--caddy-logs",
        action="append",
        default=None,
        help="Caddy log dir (repeatable). Default: /var/spark/caddy-logs. "
        "Also accepts a parent with current/caddy + archive/caddy",
    )
    ap.add_argument(
        "--fail2ban-logs",
        action="append",
        default=None,
        help="Fail2Ban log dir (repeatable). Default: /var/spark/security-logs/fail2ban",
    )
    ap.add_argument(
        "--crowdsec-logs",
        action="append",
        default=None,
        help="CrowdSec log dir (repeatable). Default: /var/spark/security-logs/crowdsec",
    )
    ap.add_argument(
        "--mikrotik-logs",
        action="append",
        default=None,
        help="MikroTik log dir (repeatable). Default: /var/spark/security-logs/mikrotik "
        "or logs-root current+archive/mikrotik",
    )
    ap.add_argument("--cscli-dump", default="", help="Optional cscli decisions list -o raw file")
    ap.add_argument("--output", default="/tmp/caddy-sec-out")
    ap.add_argument(
        "--geo-cache",
        default="/srv/spark/geocode/geocode_findings.json",
        help="Reuse prior geocode cache (durable under /srv/spark)",
    )
    ap.add_argument("--min-denied", type=int, default=5, help="Min denied hits to include Caddy-only IPs")
    ap.add_argument(
        "--min-mt-drops",
        type=int,
        default=5,
        help="Min MikroTik drop_* events to include MikroTik-only IPs",
    )
    ap.add_argument("--skip-geo", action="store_true")
    ap.add_argument("--skip-mikrotik", action="store_true", help="Do not parse MikroTik logs")
    args = ap.parse_args()

    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)

    logs_root = Path(args.logs_root) if args.logs_root else None

    caddy_paths = [Path(p) for p in (args.caddy_logs or [])]
    f2b_paths = [Path(p) for p in (args.fail2ban_logs or [])]
    cs_paths = [Path(p) for p in (args.crowdsec_logs or [])]
    mt_paths = [Path(p) for p in (args.mikrotik_logs or [])]

    if logs_root:
        caddy_paths.append(logs_root)
        f2b_paths.append(logs_root)
        cs_paths.append(logs_root)
        mt_paths.append(logs_root)

    if not caddy_paths:
        caddy_paths = [Path("/var/spark/caddy-logs")]
    if not f2b_paths:
        f2b_paths = [Path("/var/spark/security-logs/fail2ban")]
    if not cs_paths:
        cs_paths = [Path("/var/spark/security-logs/crowdsec")]
    if not mt_paths:
        mt_paths = [Path("/var/spark/security-logs/mikrotik")]

    caddy_dirs = resolve_component_dirs(caddy_paths, "caddy")
    f2b_dirs = resolve_component_dirs(f2b_paths, "fail2ban")
    cs_dirs = resolve_component_dirs(cs_paths, "crowdsec")
    mt_dirs = resolve_component_dirs(mt_paths, "mikrotik")

    caddy = parse_caddy_denied(caddy_dirs) if caddy_dirs else {}

    f2b_files: List[Path] = []
    for d in f2b_dirs:
        f2b_files.extend(iter_files(d, ("**/*",)))
    f2b = parse_fail2ban(f2b_files)

    cs_files: List[Path] = []
    for d in cs_dirs:
        cs_files.extend(iter_files(d, ("**/*",)))
    cs = parse_crowdsec(cs_files)
    cscli = load_cscli_dump(Path(args.cscli_dump) if args.cscli_dump else None)

    mt: Dict[str, Dict[str, Any]] = {}
    if not args.skip_mikrotik:
        if mt_dirs:
            mt = parse_mikrotik(mt_dirs)
        else:
            print("[mikrotik] no dirs found — skip (stage current+archive/mikrotik or pass --mikrotik-logs)")

    # Finding set: banned OR enough denied traffic OR MikroTik signal
    finding_ips: Set[str] = set()
    for ip, rec in caddy.items():
        if rec["denied_total"] >= args.min_denied:
            finding_ips.add(ip)
    finding_ips.update(f2b.keys())
    finding_ips.update(cs.keys())
    finding_ips.update(cscli.keys())
    for ip, rec in mt.items():
        if rec.get("login_failures", 0) >= 1:
            finding_ips.add(ip)
        elif rec.get("drop_total", 0) >= args.min_mt_drops:
            finding_ips.add(ip)
    print(f"[join] finding IPs={len(finding_ips):,}")

    cache = {}
    gp = Path(args.geo_cache)
    if gp.exists():
        try:
            cache = json.loads(gp.read_text(encoding="utf-8"))
            print(f"[geo] loaded cache {len(cache)} from {gp}")
        except (json.JSONDecodeError, OSError):
            pass

    # only geocode public IPs (private login-fail sources skip geo)
    public_findings = sorted(ip for ip in finding_ips if is_public_ip(ip))
    geo: Dict[str, Dict[str, Any]] = {}
    if not args.skip_geo:
        geo = geocode_all(public_findings, cache=cache)
        (out / "geocode_findings.json").write_text(json.dumps(geo, indent=2), encoding="utf-8")
    else:
        geo = {ip: cache[ip] for ip in public_findings if ip in cache}

    findings: List[Dict[str, Any]] = []
    denied_events = sum(c["denied_total"] for c in caddy.values())
    mt_drop_events = sum(r.get("drop_total", 0) for r in mt.values())
    mt_login_events = sum(r.get("login_failures", 0) for r in mt.values())

    for ip in sorted(finding_ips):
        c = caddy.get(ip)
        f = f2b.get(ip)
        s = cs.get(ip)
        d = cscli.get(ip)
        m = mt.get(ip)
        sev, rules = score_finding(c, f, s if s else d, m)
        if not rules and not f and not s and not d and not m:
            continue
        g = geo.get(ip) or {}
        paths = []
        if c and c.get("paths"):
            paths = [p for p, _ in c["paths"].most_common(8)]
        finding = {
            "ip": ip,
            "severity": sev,
            "rules": rules,
            "denied_total": (c or {}).get("denied_total") or 0,
            "n_401": (c or {}).get("n_401") or 0,
            "n_403": (c or {}).get("n_403") or 0,
            "n_429": (c or {}).get("n_429") or 0,
            "hosts": sorted(list((c or {}).get("hosts") or [])),
            "paths_sample": paths,
            "first_ts": (c or {}).get("first_ts") or (m or {}).get("first_ts"),
            "last_ts": (c or {}).get("last_ts") or (m or {}).get("last_ts"),
            "fail2ban_bans": (f or {}).get("ban_count") or 0,
            "fail2ban_increases": (f or {}).get("increase_count") or 0,
            "fail2ban_jails": sorted(list((f or {}).get("jails") or [])),
            "fail2ban_last_ban": (f or {}).get("last_ban"),
            "crowdsec_bans": (s or {}).get("ban_count") or 0,
            "crowdsec_reasons": (
                list(((s or {}).get("reasons") or Counter()).most_common(5))
                if s
                else ([((d or {}).get("reason"), 1)] if d else [])
            ),
            "crowdsec_active": bool(d),
            "mt_drop_total": (m or {}).get("drop_total") or 0,
            "mt_drop_ssh": (m or {}).get("drop_ssh") or 0,
            "mt_login_failures": (m or {}).get("login_failures") or 0,
            "mt_drop_rules": (
                list(((m or {}).get("rules") or Counter()).most_common(5)) if m else []
            ),
            "mt_login_users": (
                list(((m or {}).get("users") or Counter()).most_common(5)) if m else []
            ),
            "geo": {
                "country": g.get("country"),
                "countryCode": g.get("countryCode")
                or (s or {}).get("country_hint")
                or (d or {}).get("country_hint"),
                "city": g.get("city"),
                "regionName": g.get("regionName"),
                "lat": g.get("lat"),
                "lon": g.get("lon"),
                "isp": g.get("isp") or g.get("org"),
                "as": g.get("as"),
            },
        }
        findings.append(finding)

    findings.sort(
        key=lambda x: (
            {"high": 0, "medium": 1, "low": 2, "info": 3}.get(x["severity"], 9),
            -(x["denied_total"] or 0),
            -(x["mt_drop_total"] or 0),
            -(x["fail2ban_bans"] or 0),
        )
    )

    meta = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "finding_ips": len(findings),
        "denied_events": denied_events,
        "fail2ban_ban_ips": len(f2b),
        "crowdsec_ips": len(cs) + len(cscli),
        "mikrotik_ips": len(mt),
        "mikrotik_drop_events": mt_drop_events,
        "mikrotik_login_failures": mt_login_events,
        "min_denied": args.min_denied,
        "min_mt_drops": args.min_mt_drops,
        "logs_root": str(logs_root) if logs_root else None,
        "caddy_dirs": [str(d) for d in caddy_dirs],
        "fail2ban_dirs": [str(d) for d in f2b_dirs],
        "crowdsec_dirs": [str(d) for d in cs_dirs],
        "mikrotik_dirs": [str(d) for d in mt_dirs],
    }

    report = {"meta": meta, "findings": findings}
    (out / "findings.json").write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")

    # text report
    lines = [
        "Caddy + Fail2Ban + CrowdSec + MikroTik security scan",
        f"generated {meta['generated_at']}",
        f"findings={meta['finding_ips']} denied_events={meta['denied_events']} "
        f"fail2ban_ips={meta['fail2ban_ban_ips']} crowdsec_ips={meta['crowdsec_ips']} "
        f"mikrotik_ips={meta['mikrotik_ips']} mt_drops={meta['mikrotik_drop_events']} "
        f"mt_logins={meta['mikrotik_login_failures']}",
        f"caddy_dirs={meta['caddy_dirs']}",
        f"mikrotik_dirs={meta['mikrotik_dirs']}",
        "",
        f"{'sev':<7} {'denied':>7} {'mtDrp':>5} {'mtSSH':>5} {'mtL':>3} {'f2b':>4} {'cs':>3}  "
        f"{'ip':<16}  country / isp / rules",
        "-" * 120,
    ]
    for f in findings[:80]:
        g = f.get("geo") or {}
        lines.append(
            f"{f['severity']:<7} {f['denied_total']:7d} {f['mt_drop_total']:5d} {f['mt_drop_ssh']:5d} "
            f"{f['mt_login_failures']:3d} {f['fail2ban_bans']:4d} {f['crowdsec_bans']:3d}  {f['ip']:<16}  "
            f"{g.get('country') or '—'} | {(g.get('isp') or '—')[:28]} | {','.join(f['rules'])}"
        )
    text = "\n".join(lines) + "\n"
    (out / "report.txt").write_text(text, encoding="utf-8")
    print(text[:3000])
    if len(text) > 3000:
        print(f"... ({len(findings)} findings total, see report.txt)")

    render_security_map(out / "security_map.html", findings, meta)
    print(f"[done] {out / 'findings.json'}")
    print(f"[done] {out / 'report.txt'}")
    print(f"[done] {out / 'security_map.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
