#!/usr/bin/env python3
# =============================================================================
# mikrotik_log_insights.py
# Version: 1.0
# Date: 2026-08-12
#
# Insights over MikroTik syslog exports (current + archive .gz).
#
# Focus: firewall drops / WAN hits, auth, DHCP churn, WireGuard, link events.
# Reads plain *.log and *.gz (streamed — no disk unzip). Skips *.tar.gz.
#
# Example:
#   python3 mikrotik_log_insights.py \
#     --logs-root /mnt/caddy-logs \
#     --output /tmp/mikrotik-insights \
#     --geo-top 40
#
# Paths: reverse-proxy layout current/mikrotik + archive/mikrotik under --logs-root,
# or pass --mikrotik-logs repeatedly for flat dirs.
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
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

# 2026-07-13T00:07:49.856131+01:00 192.168.50.1 firewall,info drop_ssh input: ...
TS_RE = re.compile(r"^(?P<ts>\d{4}-\d{2}-\d{2}T[^\s]+)")
TOPIC_RE = re.compile(
    r"\s(?P<router>\d{1,3}(?:\.\d{1,3}){3})\s+(?P<topics>[a-z0-9_,]+)\s+(?P<body>.*)$",
    re.IGNORECASE,
)
FW_RULE_RE = re.compile(
    r"firewall,[a-z]+\s+(?P<rule>[A-Za-z0-9_:-]+)\s+(?P<chain>input|forward|dstnat|srcnat)?",
    re.IGNORECASE,
)
CONN_RE = re.compile(
    r"(?P<src>\d{1,3}(?:\.\d{1,3}){3}):(?P<sport>\d+)->"
    r"(?P<dst>\d{1,3}(?:\.\d{1,3}){3}):(?P<dport>\d+)"
)
IN_IFACE_RE = re.compile(r"\bin:(?P<iface>[^\s,]+)")
PROTO_RE = re.compile(r"\bproto\s+(?P<proto>[A-Za-z0-9/]+)")
LOGIN_FAIL_RE = re.compile(
    r"login failure for user (?P<user>\S+) from (?P<ip>\S+) via (?P<via>\S+)",
    re.IGNORECASE,
)
LOGIN_OK_RE = re.compile(
    r"user (?P<user>\S+) logged in from (?P<ip>\S+) via (?P<via>\S+)",
    re.IGNORECASE,
)
SSH_KEY_RE = re.compile(
    r"publickey accepted for user:\s*(?P<user>\S+)",
    re.IGNORECASE,
)
DHCP_RE = re.compile(
    r"dhcp,[a-z]+\s+(?P<pool>\S+)\s+(?P<action>assigned|deassigned)\s+"
    r"(?P<ip>\S+)(?:\s+for\s+(?P<mac>\S+))?(?:\s+(?P<host>\S+))?",
    re.IGNORECASE,
)
WG_PEER_RE = re.compile(
    r"wireguard\d*:\s*\[(?P<peer>[^\]]+)\].*?(?P<msg>Handshake.*|.*)",
    re.IGNORECASE,
)
LINK_RE = re.compile(
    r"(?P<iface>\S+)\s+link\s+(?P<state>up|down)",
    re.IGNORECASE,
)

DROP_RULE_HINTS = ("drop_", "isolate_", "invalid", "blacklist", "block")


def is_public_ip(ip: str) -> bool:
    if not ip or ":" in ip:  # skip v6 for geo simplicity
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
    return True


def open_text(path: Path):
    if path.suffix == ".gz" or path.name.endswith(".gz"):
        return gzip.open(path, "rt", errors="ignore")
    return open(path, "rt", errors="ignore")


def iter_log_files(roots: List[Path]) -> List[Path]:
    files: List[Path] = []
    seen: Set[str] = set()
    for root in roots:
        if not root.exists():
            print(f"[paths] missing {root}", file=sys.stderr)
            continue
        if root.is_file():
            candidates = [root]
        else:
            candidates = list(root.rglob("*"))
        for p in candidates:
            if not p.is_file():
                continue
            if p.name.endswith((".tar.gz", ".tgz")):
                continue
            name = p.name.lower()
            if not (
                name.endswith((".log", ".gz"))
                or "mikrotik" in name
                or name.startswith("log.")
            ):
                # still allow plain rotated names like mikrotik-2026-….gz
                if ".gz" not in name and not name.endswith(".log"):
                    continue
            key = str(p.resolve()) if p.exists() else str(p)
            if key in seen:
                continue
            seen.add(key)
            files.append(p)
    return sorted(files)


def resolve_mikrotik_dirs(paths: List[Path], logs_root: Optional[Path]) -> List[Path]:
    found: List[Path] = []
    seen: Set[str] = set()

    def add(p: Path) -> None:
        if p.exists() and str(p) not in seen:
            seen.add(str(p))
            found.append(p)

    all_paths = list(paths)
    if logs_root:
        all_paths.append(logs_root)

    for raw in all_paths:
        p = raw.expanduser()
        if not p.exists():
            continue
        cur = p / "current" / "mikrotik"
        arc = p / "archive" / "mikrotik"
        if cur.is_dir() or arc.is_dir():
            if cur.is_dir():
                add(cur)
            if arc.is_dir():
                add(arc)
            continue
        if p.name == "mikrotik" or p.is_dir():
            add(p)
    return found


def day_key(ts: Optional[str]) -> str:
    if not ts:
        return "unknown"
    return ts[:10]  # YYYY-MM-DD


def parse_logs(files: List[Path]) -> Dict[str, Any]:
    topics = Counter()
    fw_rules = Counter()
    fw_chains = Counter()
    drop_rules = Counter()
    drop_src = Counter()
    drop_src_by_rule: Dict[str, Counter] = defaultdict(Counter)
    wan_dstnat = Counter()  # rule -> count for dstnat from public
    wan_src = Counter()
    dports = Counter()
    in_ifaces = Counter()
    protos = Counter()

    login_fail: List[Dict[str, str]] = []
    login_ok: List[Dict[str, str]] = []
    login_fail_users = Counter()
    login_ok_users = Counter()
    login_fail_src = Counter()

    dhcp_assign = Counter()  # ip
    dhcp_deassign = Counter()
    dhcp_hosts = Counter()
    dhcp_macs = Counter()

    wg_fail = Counter()  # peer
    wg_msgs = Counter()
    link_events: List[Dict[str, str]] = []
    script_errors = 0
    pppoe_events = 0

    first_ts: Optional[str] = None
    last_ts: Optional[str] = None
    lines_total = 0
    by_day = Counter()

    print(f"[mikrotik] scanning {len(files)} files")
    for fp in files:
        try:
            with open_text(fp) as fh:
                for line in fh:
                    lines_total += 1
                    line = line.rstrip("\n")
                    if not line:
                        continue
                    tm = TS_RE.match(line)
                    ts = tm.group("ts") if tm else None
                    if ts:
                        if first_ts is None or ts < first_ts:
                            first_ts = ts
                        if last_ts is None or ts > last_ts:
                            last_ts = ts
                        by_day[day_key(ts)] += 1

                    # --- auth ---
                    lf = LOGIN_FAIL_RE.search(line)
                    if lf:
                        ip = lf.group("ip").rstrip(",")
                        user = lf.group("user")
                        via = lf.group("via").rstrip(",")
                        login_fail.append(
                            {"ts": ts or "", "user": user, "ip": ip, "via": via}
                        )
                        login_fail_users[user] += 1
                        login_fail_src[ip] += 1
                        continue
                    lo = LOGIN_OK_RE.search(line)
                    if lo:
                        ip = lo.group("ip").rstrip(",")
                        user = lo.group("user")
                        via = lo.group("via").rstrip(",")
                        login_ok.append(
                            {"ts": ts or "", "user": user, "ip": ip, "via": via}
                        )
                        login_ok_users[user] += 1
                        continue
                    sk = SSH_KEY_RE.search(line)
                    if sk:
                        topics["ssh"] += 1
                        continue

                    # --- dhcp ---
                    dm = DHCP_RE.search(line)
                    if dm:
                        topics["dhcp"] += 1
                        ip = dm.group("ip")
                        if dm.group("action").lower() == "assigned":
                            dhcp_assign[ip] += 1
                        else:
                            dhcp_deassign[ip] += 1
                        if dm.group("host"):
                            dhcp_hosts[dm.group("host")] += 1
                        if dm.group("mac"):
                            dhcp_macs[dm.group("mac")] += 1
                        continue

                    # --- wireguard ---
                    if "wireguard" in line.lower():
                        topics["wireguard"] += 1
                        if "handshake" in line.lower() and (
                            "did not complete" in line.lower()
                            or "retrying" in line.lower()
                            or "timeout" in line.lower()
                        ):
                            wm = WG_PEER_RE.search(line)
                            peer = wm.group("peer") if wm else "unknown"
                            wg_fail[peer] += 1
                            wg_msgs[line.strip()[-120:]] += 1
                        continue

                    # --- link / interface ---
                    if "link up" in line.lower() or "link down" in line.lower():
                        topics["interface"] += 1
                        lm = LINK_RE.search(line)
                        if lm:
                            link_events.append(
                                {
                                    "ts": ts or "",
                                    "iface": lm.group("iface"),
                                    "state": lm.group("state").lower(),
                                }
                            )
                        continue

                    if "script,error" in line or "script,critical" in line:
                        topics["script"] += 1
                        script_errors += 1
                        continue

                    # PPPoE *topic* only (e.g. "… pppoe,ppp,info …").
                    # Do not match firewall lines that merely use in:pppoe-out1 —
                    # those must fall through to firewall/drop/WAN parsing.
                    tm_pppoe = TOPIC_RE.search(line)
                    if tm_pppoe and "pppoe" in tm_pppoe.group("topics").lower():
                        topics["pppoe"] += 1
                        pppoe_events += 1
                        continue

                    # --- firewall ---
                    if "firewall," not in line:
                        # generic topic count
                        tm2 = TOPIC_RE.search(line)
                        if tm2:
                            topics[tm2.group("topics").split(",")[0].lower()] += 1
                        continue

                    topics["firewall"] += 1
                    fr = FW_RULE_RE.search(line)
                    rule = fr.group("rule") if fr else "unknown"
                    chain = (fr.group("chain") or "").lower() if fr else ""
                    # normalize "input:" style
                    if rule.endswith(":"):
                        rule = rule.rstrip(":")
                    fw_rules[rule] += 1
                    if chain:
                        fw_chains[chain] += 1

                    iface_m = IN_IFACE_RE.search(line)
                    if iface_m:
                        in_ifaces[iface_m.group("iface")] += 1
                    pr = PROTO_RE.search(line)
                    if pr:
                        protos[pr.group("proto")] += 1

                    cm = CONN_RE.search(line)
                    src = sport = dst = dport = None
                    if cm:
                        src, sport = cm.group("src"), cm.group("sport")
                        dst, dport = cm.group("dst"), cm.group("dport")
                        dports[dport] += 1

                    rule_l = rule.lower()
                    is_drop = any(h in rule_l for h in DROP_RULE_HINTS) or rule_l == "drop"
                    if is_drop and src and is_public_ip(src):
                        drop_rules[rule] += 1
                        drop_src[src] += 1
                        drop_src_by_rule[rule][src] += 1
                    elif chain == "dstnat" and src and is_public_ip(src):
                        wan_dstnat[rule] += 1
                        wan_src[src] += 1
        except OSError as e:
            print(f"[mikrotik] skip {fp}: {e}", file=sys.stderr)

    return {
        "lines_total": lines_total,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "topics": topics,
        "fw_rules": fw_rules,
        "fw_chains": fw_chains,
        "drop_rules": drop_rules,
        "drop_src": drop_src,
        "drop_src_by_rule": {k: dict(v.most_common(20)) for k, v in drop_src_by_rule.items()},
        "wan_dstnat": wan_dstnat,
        "wan_src": wan_src,
        "dports": dports,
        "in_ifaces": in_ifaces,
        "protos": protos,
        "login_fail": login_fail,
        "login_ok": login_ok,
        "login_fail_users": login_fail_users,
        "login_ok_users": login_ok_users,
        "login_fail_src": login_fail_src,
        "dhcp_assign": dhcp_assign,
        "dhcp_deassign": dhcp_deassign,
        "dhcp_hosts": dhcp_hosts,
        "dhcp_macs": dhcp_macs,
        "wg_fail": wg_fail,
        "wg_msgs": wg_msgs,
        "link_events": link_events[-50:],  # last 50 kept in full parse order-ish
        "script_errors": script_errors,
        "pppoe_events": pppoe_events,
        "by_day": by_day,
        "files": len(files),
    }


def geocode_ips(ips: List[str], pause: float = 4.1) -> Dict[str, Dict[str, Any]]:
    geo: Dict[str, Dict[str, Any]] = {}
    need = [ip for ip in ips if is_public_ip(ip)]
    print(f"[geo] fetching {len(need)} IPs")
    for i in range(0, len(need), 100):
        batch = need[i : i + 100]
        body = json.dumps(
            [
                {
                    "query": ip,
                    "fields": "status,country,countryCode,city,lat,lon,isp,org,as,query",
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


def top(counter: Counter, n: int = 15) -> List[Tuple[str, int]]:
    return list(counter.most_common(n))


def render_report(data: Dict[str, Any], geo: Dict[str, Dict[str, Any]], out: Path) -> str:
    lines: List[str] = []
    lines.append("MikroTik log insights")
    lines.append(f"generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
    lines.append(
        f"files={data['files']} lines={data['lines_total']:,} "
        f"span={data.get('first_ts')} → {data.get('last_ts')}"
    )
    lines.append("")

    lines.append("## Topics")
    for k, v in top(data["topics"], 20):
        lines.append(f"  {v:8d}  {k}")
    lines.append("")

    lines.append("## Firewall rules (all)")
    for k, v in top(data["fw_rules"], 20):
        lines.append(f"  {v:8d}  {k}")
    lines.append("")

    lines.append("## Drop / isolate (public sources)")
    for k, v in top(data["drop_rules"], 15):
        lines.append(f"  {v:8d}  {k}")
    lines.append("  Top public drop sources:")
    for ip, v in top(data["drop_src"], 15):
        g = geo.get(ip) or {}
        loc = g.get("country") or "—"
        isp = (g.get("isp") or g.get("org") or "—")[:40]
        lines.append(f"    {v:6d}  {ip:<16}  {loc} | {isp}")
    lines.append("")

    lines.append("## WAN dstnat (public → published services)")
    for k, v in top(data["wan_dstnat"], 15):
        lines.append(f"  {v:8d}  {k}")
    lines.append("  Top public clients:")
    for ip, v in top(data["wan_src"], 12):
        g = geo.get(ip) or {}
        lines.append(
            f"    {v:6d}  {ip:<16}  {g.get('country') or '—'} | "
            f"{(g.get('isp') or '—')[:40]}"
        )
    lines.append("")

    lines.append("## Top destination ports (conn tuples)")
    for k, v in top(data["dports"], 15):
        lines.append(f"  {v:8d}  :{k}")
    lines.append("")

    lines.append("## Auth")
    lines.append(f"  login OK:   {len(data['login_ok'])}")
    lines.append(f"  login FAIL: {len(data['login_fail'])}")
    if data["login_fail"]:
        lines.append("  Failures:")
        for e in data["login_fail"][-20:]:
            lines.append(
                f"    {e['ts']}  user={e['user']} from={e['ip']} via={e['via']}"
            )
    if data["login_ok_users"]:
        lines.append("  Successful users:")
        for u, v in top(data["login_ok_users"], 10):
            lines.append(f"    {v:4d}  {u}")
    lines.append("")

    lines.append("## DHCP churn")
    lines.append(f"  assigns:   {sum(data['dhcp_assign'].values()):,}")
    lines.append(f"  deassigns: {sum(data['dhcp_deassign'].values()):,}")
    lines.append("  Busiest hosts (name tag):")
    for k, v in top(data["dhcp_hosts"], 12):
        lines.append(f"    {v:6d}  {k}")
    lines.append("  Most re-assigned IPs:")
    for k, v in top(data["dhcp_assign"], 10):
        lines.append(f"    {v:6d}  {k}")
    lines.append("")

    lines.append("## WireGuard handshake problems")
    if data["wg_fail"]:
        for k, v in top(data["wg_fail"], 15):
            lines.append(f"  {v:6d}  peer [{k}]")
    else:
        lines.append("  (none matched)")
    lines.append("")

    lines.append("## Link flaps (sample of recent)")
    if data["link_events"]:
        for e in data["link_events"][-15:]:
            lines.append(f"  {e['ts']}  {e['iface']} {e['state']}")
    else:
        lines.append("  (none)")
    lines.append("")

    lines.append("## Volume by day")
    for day, v in sorted(data["by_day"].items()):
        lines.append(f"  {day}  {v:8d}")
    lines.append("")

    lines.append("## Other")
    lines.append(f"  script errors: {data['script_errors']}")
    lines.append(f"  pppoe-related lines: {data['pppoe_events']}")
    lines.append(f"  top in: ifaces: {top(data['in_ifaces'], 8)}")
    lines.append("")

    text = "\n".join(lines) + "\n"
    (out / "report.txt").write_text(text, encoding="utf-8")
    return text


def render_html(data: Dict[str, Any], geo: Dict[str, Dict[str, Any]], out: Path) -> None:
    """Dark single-file dashboard + optional drop-source map pins."""
    points = []
    for ip, cnt in data["drop_src"].most_common(200):
        g = geo.get(ip) or {}
        if g.get("lat") is None:
            continue
        points.append(
            {
                "ip": ip,
                "lat": g["lat"],
                "lon": g["lon"],
                "n": cnt,
                "country": g.get("country") or "",
                "isp": g.get("isp") or g.get("org") or "",
            }
        )

    def j(obj: Any) -> str:
        return json.dumps(obj, default=str)

    topics = top(data["topics"], 12)
    rules = top(data["fw_rules"], 12)
    drops = top(data["drop_src"], 15)
    days = sorted(data["by_day"].items())

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>MikroTik log insights</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    :root {{ --bg:#0d1117; --card:#161b22; --text:#e6edf3; --muted:#8b949e; --acc:#58a6ff; --bad:#f85149; --ok:#3fb950; }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; font-family: ui-sans-serif, system-ui, sans-serif; background:var(--bg); color:var(--text); }}
    header {{ padding:1.2rem 1.5rem; border-bottom:1px solid #30363d; }}
    h1 {{ margin:0 0 .3rem; font-size:1.35rem; font-weight:600; }}
    .sub {{ color:var(--muted); font-size:.9rem; }}
    main {{ display:grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap:1rem; padding:1rem 1.5rem 2rem; }}
    .card {{ background:var(--card); border:1px solid #30363d; border-radius:10px; padding:1rem 1.1rem; }}
    .card h2 {{ margin:0 0 .75rem; font-size:1rem; color:var(--acc); font-weight:600; }}
    .bar {{ display:flex; align-items:center; gap:.5rem; margin:.28rem 0; font-size:.82rem; }}
    .bar .label {{ width:9rem; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:var(--muted); }}
    .bar .track {{ flex:1; background:#21262d; border-radius:4px; height:8px; overflow:hidden; }}
    .bar .fill {{ height:100%; background:linear-gradient(90deg,#1f6feb,#58a6ff); border-radius:4px; }}
    .bar .n {{ width:3.5rem; text-align:right; font-variant-numeric:tabular-nums; }}
    .stat {{ font-size:1.6rem; font-weight:700; }}
    .stat span {{ font-size:.85rem; color:var(--muted); font-weight:500; margin-left:.4rem; }}
    #map {{ height:360px; border-radius:8px; }}
    table {{ width:100%; border-collapse:collapse; font-size:.8rem; }}
    td, th {{ padding:.3rem .4rem; text-align:left; border-bottom:1px solid #21262d; }}
    th {{ color:var(--muted); font-weight:500; }}
    .bad {{ color:var(--bad); }} .ok {{ color:var(--ok); }}
    .mono {{ font-family: ui-monospace, monospace; }}
    .wide {{ grid-column: 1 / -1; }}
  </style>
</head>
<body>
  <header>
    <h1>MikroTik log insights</h1>
    <div class="sub">lines {data['lines_total']:,} · files {data['files']} ·
      {data.get('first_ts') or '—'} → {data.get('last_ts') or '—'}</div>
  </header>
  <main>
    <div class="card">
      <h2>At a glance</h2>
      <div class="stat">{sum(data['drop_rules'].values()):,}<span>public drops</span></div>
      <div class="stat" style="font-size:1.2rem;margin-top:.6rem">{len(data['login_fail'])}<span class="bad">login fails</span>
        · {len(data['login_ok'])}<span class="ok">logins ok</span></div>
      <div class="stat" style="font-size:1.2rem;margin-top:.6rem">{sum(data['wg_fail'].values()):,}<span>WG handshake issues</span></div>
      <div class="stat" style="font-size:1.2rem;margin-top:.6rem">{sum(data['dhcp_assign'].values()):,}<span>DHCP assigns</span></div>
    </div>
    <div class="card">
      <h2>Topics</h2>
      <div id="topics"></div>
    </div>
    <div class="card">
      <h2>Firewall rules</h2>
      <div id="rules"></div>
    </div>
    <div class="card">
      <h2>Public drop sources</h2>
      <div id="drops"></div>
    </div>
    <div class="card wide">
      <h2>Drop sources map (geocoded)</h2>
      <div id="map"></div>
    </div>
    <div class="card wide">
      <h2>Volume by day</h2>
      <div id="days"></div>
    </div>
    <div class="card wide">
      <h2>Login failures</h2>
      <table><thead><tr><th>When</th><th>User</th><th>From</th><th>Via</th></tr></thead>
      <tbody id="logins"></tbody></table>
    </div>
  </main>
  <script>
    const topics = {j(topics)};
    const rules = {j(rules)};
    const drops = {j(drops)};
    const days = {j(days)};
    const logins = {j(data['login_fail'][-30:])};
    const points = {j(points)};

    function bars(el, rows, color) {{
      const max = Math.max(1, ...rows.map(r => r[1]));
      el.innerHTML = rows.map(([lab, n]) => `
        <div class="bar">
          <div class="label" title="${{lab}}">${{lab}}</div>
          <div class="track"><div class="fill" style="width:${{100*n/max}}%;background:${{color||''}}"></div></div>
          <div class="n">${{n.toLocaleString()}}</div>
        </div>`).join('');
    }}
    bars(document.getElementById('topics'), topics);
    bars(document.getElementById('rules'), rules);
    bars(document.getElementById('drops'), drops, 'linear-gradient(90deg,#da3633,#f85149)');
    bars(document.getElementById('days'), days.map(([d,n]) => [d, n]));

    document.getElementById('logins').innerHTML = logins.length
      ? logins.map(e => `<tr><td class="mono">${{e.ts}}</td><td>${{e.user}}</td>
          <td class="mono">${{e.ip}}</td><td>${{e.via}}</td></tr>`).join('')
      : '<tr><td colspan="4" class="ok">None</td></tr>';

    const map = L.map('map', {{ zoomControl: true }}).setView([20, 0], 2);
    L.tileLayer('https://{{s}}.basemaps.cartocdn.com/dark_all/{{z}}/{{x}}/{{y}}{{r}}.png', {{
      attribution: '&copy; OSM &copy; CARTO', maxZoom: 18
    }}).addTo(map);
    const layer = L.layerGroup().addTo(map);
    points.forEach(p => {{
      const r = Math.max(2, Math.min(8, 1.5 + Math.log10(p.n+1)*1.5));
      L.circleMarker([p.lat, p.lon], {{
        radius: r, color: '#f85149', fillColor: '#f85149', fillOpacity: 0.75, weight: 0.5
      }}).bindPopup(`<b class="mono">${{p.ip}}</b><br/>drops: <b>${{p.n}}</b><br/>${{p.country}}<br/><small>${{p.isp}}</small>`)
        .addTo(layer);
    }});
    if (points.length) map.fitBounds(layer.getBounds().pad(0.2));
  </script>
</body>
</html>
"""
    (out / "insights.html").write_text(html, encoding="utf-8")


def counters_to_json(data: Dict[str, Any]) -> Dict[str, Any]:
    """Serialize Counters for findings.json."""
    out = {}
    for k, v in data.items():
        if isinstance(v, Counter):
            out[k] = v.most_common(50)
        elif isinstance(v, list):
            out[k] = v[-100:] if k in ("login_fail", "login_ok", "link_events") else v
        else:
            out[k] = v
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="MikroTik syslog insights (current + archive)")
    ap.add_argument(
        "--logs-root",
        default="",
        help="Reverse-proxy style root with current/mikrotik + archive/mikrotik",
    )
    ap.add_argument(
        "--mikrotik-logs",
        action="append",
        default=None,
        help="Extra mikrotik log dir (repeatable)",
    )
    ap.add_argument("--output", default="/tmp/mikrotik-insights")
    ap.add_argument(
        "--geo-top",
        type=int,
        default=40,
        help="Geocode top N public drop + WAN client IPs (0=skip)",
    )
    args = ap.parse_args()

    roots = resolve_mikrotik_dirs(
        [Path(p) for p in (args.mikrotik_logs or [])],
        Path(args.logs_root) if args.logs_root else None,
    )
    if not roots:
        # sensible defaults
        roots = resolve_mikrotik_dirs(
            [],
            Path("/mnt/caddy-logs") if Path("/mnt/caddy-logs").exists() else None,
        )
    if not roots:
        print("No MikroTik log dirs found. Pass --logs-root /mnt/caddy-logs", file=sys.stderr)
        return 1

    print(f"[paths] {', '.join(str(r) for r in roots)}")
    files = iter_log_files(roots)
    if not files:
        print("No log files matched.", file=sys.stderr)
        return 1

    data = parse_logs(files)

    # geo: top drop sources + top WAN clients
    geo: Dict[str, Dict[str, Any]] = {}
    if args.geo_top > 0:
        want: List[str] = []
        for ip, _ in data["drop_src"].most_common(args.geo_top):
            want.append(ip)
        for ip, _ in data["wan_src"].most_common(args.geo_top):
            if ip not in want:
                want.append(ip)
        geo = geocode_ips(want[: max(args.geo_top * 2, args.geo_top)])

    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)

    text = render_report(data, geo, out)
    render_html(data, geo, out)

    payload = {
        "meta": {
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
            "roots": [str(r) for r in roots],
            "files": data["files"],
            "lines_total": data["lines_total"],
            "first_ts": data["first_ts"],
            "last_ts": data["last_ts"],
        },
        "summary": counters_to_json(data),
        "geo": geo,
    }
    (out / "insights.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")

    print(text[:3500])
    if len(text) > 3500:
        print(f"... (full report: {out / 'report.txt'})")
    print(f"[done] {out / 'report.txt'}")
    print(f"[done] {out / 'insights.json'}")
    print(f"[done] {out / 'insights.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
