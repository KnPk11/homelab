#!/usr/bin/env python3
# =============================================================================
# caddy_geo_map.py
# Version: 1.0
# Date: 2026-08-12
#
# Distributed Caddy access-log analytics → interactive geo map (Leaflet)
#
# Reads Caddy JSON access logs (one JSON object per line), aggregates public
# client IPs with Spark, optional free ip-api.com geolocation for the top-N
# talkers, and writes a self-contained HTML map + CSV/JSON summaries.
#
# Data locality note: /mnt/logs lives on reverse-proxy. For multi-node Spark
# (lab-vm + scratch-pc), mount the logs SMB share at the same path on every
# worker (see run_caddy_geo_map.sh + spark setup docs / Proxmox file-svc).
# Supports plain *.log / *.jsonl and gzipped *.gz archives.
# =============================================================================
from __future__ import annotations

import argparse
import ipaddress
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# pyspark imported lazily so HTML rebuild helpers work without Spark on PATH

# Combined log (plaintext) fallback: IP - - [ts] "METHOD path proto" status size
COMBINED_RE = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<ts>[^\]]+)\] '
    r'"(?P<method>\S+) (?P<path>\S+)(?: \S+)?" (?P<status>\d{3}) (?P<size>\S+)'
)

PRIVATE_NETS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
]


def is_public_ip(ip: str) -> bool:
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return not any(addr in net for net in PRIVATE_NETS)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Spark Caddy log → geo map")
    p.add_argument(
        "--input",
        required=True,
        help="Directory of Caddy logs (recurse: *.log, *.jsonl, *.gz under tree)",
    )
    p.add_argument(
        "--output",
        default="/tmp/caddy-geo-out",
        help="Output directory for map + summaries (default: /tmp/caddy-geo-out)",
    )
    p.add_argument("--partitions", type=int, default=16, help="Repartition factor")
    p.add_argument(
        "--top-n",
        type=int,
        default=150,
        help="Max IPs to geocode (budget cap; default 150). Used with --min-requests.",
    )
    p.add_argument(
        "--min-requests",
        type=int,
        default=0,
        help="Geocode every public IP with at least this many requests "
        "(0 = classic top-N only). Example: --min-requests 20 --top-n 3000 "
        "includes quieter clients in country totals.",
    )
    p.add_argument(
        "--skip-geo",
        action="store_true",
        help="Skip geolocation (Spark aggregates only)",
    )
    p.add_argument(
        "--include-private",
        action="store_true",
        help="Keep RFC1918/link-local clients in aggregates (default: public only)",
    )
    p.add_argument(
        "--reuse-geo",
        action="store_true",
        help="Reuse geocode.json in --output if present; only fetch missing IPs",
    )
    return p.parse_args()


def build_spark(app_name: str):
    from pyspark.sql import SparkSession

    return (
        SparkSession.builder.appName(app_name)
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.sql.files.ignoreCorruptFiles", "true")
        .getOrCreate()
    )


def list_log_files(input_path: str) -> List[str]:
    """Recurse for live + rotated/gzipped Caddy logs (skip multi-file tar snapshots)."""
    root = Path(input_path)
    if not root.exists():
        raise FileNotFoundError(f"input path not found: {input_path}")
    if root.is_file():
        return [str(root.resolve())]

    found: List[str] = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        name = p.name.lower()
        if name.endswith((".tar.gz", ".tgz")):
            continue
        if name.endswith((".log", ".json", ".jsonl", ".log.gz", ".json.gz", ".gz")):
            found.append(str(p.resolve()))

    out = sorted(set(found))
    if not out:
        raise FileNotFoundError(f"no log files under {input_path}")
    return out


def _looks_like_json_log(path: str) -> bool:
    """Sniff first non-empty line (handles .gz). Path heuristics are not enough
    when logs are staged flat (e.g. /tmp/caddy-json-logs/*.log)."""
    import gzip

    openers = []
    if path.endswith(".gz"):
        openers.append(lambda: gzip.open(path, "rt", errors="ignore"))
    openers.append(lambda: open(path, "rt", errors="ignore"))

    for opener in openers:
        try:
            with opener() as fh:
                for _ in range(20):
                    line = fh.readline()
                    if not line:
                        break
                    s = line.strip()
                    if not s:
                        continue
                    return s.startswith("{")
        except OSError:
            continue
    # Fallback path heuristics
    p = path.replace("\\", "/").lower()
    if "/json/" in p:
        return True
    return p.endswith((".json", ".jsonl", ".json.gz"))


def _select_caddy_json(raw):
    from pyspark.sql import functions as F

    return raw.select(
        F.coalesce(F.col("request.client_ip"), F.col("request.remote_ip")).alias("ip"),
        F.col("request.host").alias("host"),
        F.col("request.uri").alias("uri"),
        F.col("request.method").alias("method"),
        F.col("status").cast("int").alias("status"),
        F.col("ts").cast("double").alias("ts"),
        F.col("duration").cast("double").alias("duration"),
        F.col("size").cast("long").alias("size"),
        F.element_at(F.col("request.headers")["User-Agent"], 1).alias("user_agent"),
    )


def _load_plaintext(spark, files: List[str], partitions: int):
    """Combined-log lines via Spark SQL regex (no Python workers). .gz auto-decompressed."""
    from pyspark.sql import functions as F

    text = spark.read.text(files).repartition(partitions)
    parsed = (
        text.select(
            F.regexp_extract(F.col("value"), r'^(\S+)', 1).alias("ip"),
            F.lit(None).cast("string").alias("host"),
            F.regexp_extract(F.col("value"), r'"(\S+)\s+(\S+)', 2).alias("uri"),
            F.regexp_extract(F.col("value"), r'"(\S+)\s+', 1).alias("method"),
            F.regexp_extract(F.col("value"), r'" (\d{3}) ', 1).cast("int").alias("status"),
            F.lit(None).cast("double").alias("ts"),
            F.lit(None).cast("double").alias("duration"),
            F.regexp_extract(F.col("value"), r'" \d{3} (\S+)', 1).alias("size_raw"),
            F.lit(None).cast("string").alias("user_agent"),
        )
        .withColumn(
            "size",
            F.when(F.col("size_raw").rlike(r"^\d+$"), F.col("size_raw").cast("long")).otherwise(
                F.lit(0)
            ),
        )
        .drop("size_raw")
        .filter(F.col("ip") != "")
        .filter(F.col("status").isNotNull())
    )
    return parsed


def load_events(spark, input_path: str, partitions: int):
    """Load Caddy JSON and/or combined plaintext logs (plain + gzip)."""
    files = list_log_files(input_path)
    json_files = [f for f in files if _looks_like_json_log(f)]
    plain_files = [f for f in files if f not in set(json_files)]
    print(
        f"[spark] discovered {len(files)} files "
        f"({len(json_files)} json-ish, {len(plain_files)} plaintext/other)"
    )

    frames = []

    if json_files:
        raw = spark.read.option("mode", "PERMISSIVE").json(json_files)
        if "request" in set(raw.columns):
            frames.append(_select_caddy_json(raw))
        else:
            plain_files = list(dict.fromkeys(plain_files + json_files))

    if plain_files:
        frames.append(_load_plaintext(spark, plain_files, partitions))

    if not frames:
        raise RuntimeError(f"no parseable events under {input_path}")

    df = frames[0]
    for extra in frames[1:]:
        df = df.unionByName(extra, allowMissingColumns=True)

    from pyspark.sql import functions as F

    df = df.filter(F.col("ip").isNotNull() & (F.col("ip") != ""))
    return df.repartition(partitions)


def _parse_combined_line(line: str) -> Optional[Tuple]:
    m = COMBINED_RE.match(line.strip())
    if not m:
        return None
    # no reliable host in combined log; leave empty
    try:
        status = int(m.group("status"))
    except ValueError:
        status = None
    size_s = m.group("size")
    try:
        size = int(size_s) if size_s != "-" else 0
    except ValueError:
        size = 0
    return (
        m.group("ip"),
        None,
        m.group("path"),
        m.group("method"),
        status,
        None,
        None,
        size,
        None,
    )


def filter_scope(df, include_private: bool):
    """Drop RFC1918 / link-local with pure Spark SQL (no Python UDF — required for
    Spark-on-K8s when driver Python != executor image Python)."""
    from pyspark.sql import functions as F

    if include_private:
        return df
    private = (
        F.col("ip").rlike(r"^10\.")
        | F.col("ip").rlike(r"^127\.")
        | F.col("ip").rlike(r"^192\.168\.")
        | F.col("ip").rlike(r"^172\.(1[6-9]|2[0-9]|3[0-1])\.")
        | F.col("ip").rlike(r"^169\.254\.")
        | F.col("ip").rlike(r"^::1$")
        | F.col("ip").rlike(r"^(fc|fd)")
        | F.col("ip").rlike(r"^fe80:")
    )
    return df.filter(~private)


def aggregate(df):
    from pyspark.sql import functions as F

    by_ip = (
        df.groupBy("ip")
        .agg(
            F.count(F.lit(1)).alias("requests"),
            F.sum(F.when(F.col("status") >= 400, 1).otherwise(0)).alias("errors_4xx5xx"),
            F.sum(F.when((F.col("status") >= 400) & (F.col("status") < 500), 1).otherwise(0)).alias(
                "http_4xx"
            ),
            F.sum(F.when(F.col("status") >= 500, 1).otherwise(0)).alias("http_5xx"),
            F.countDistinct("host").alias("hosts_hit"),
            F.countDistinct("uri").alias("unique_paths"),
            F.min("ts").alias("first_ts"),
            F.max("ts").alias("last_ts"),
            F.sum(F.coalesce(F.col("size"), F.lit(0))).alias("bytes"),
        )
        .orderBy(F.desc("requests"))
    )

    by_host = (
        df.groupBy("host")
        .agg(F.count(F.lit(1)).alias("requests"), F.countDistinct("ip").alias("unique_ips"))
        .orderBy(F.desc("requests"))
    )

    by_status = df.groupBy("status").agg(F.count(F.lit(1)).alias("requests")).orderBy("status")

    classified = df.withColumn(
        "path_class",
        F.when(F.col("uri").rlike(r"(?i)^/\.env"), ".env probes")
        .when(F.col("uri").rlike(r"(?i)wp-admin|wp-login|xmlrpc"), "WordPress probes")
        .when(F.col("uri").rlike(r"(?i)phpmyadmin|\.php$"), "PHP probes")
        .when(F.col("uri").rlike(r"(?i)^/\.git"), "git probes")
        .when(F.col("uri").rlike(r"(?i)actuator|debug|swagger|graphql"), "API recon")
        .otherwise("other"),
    )
    by_class = (
        classified.groupBy("path_class")
        .agg(F.count(F.lit(1)).alias("requests"))
        .orderBy(F.desc("requests"))
    )

    totals = df.agg(
        F.count(F.lit(1)).alias("total_requests"),
        F.countDistinct("ip").alias("unique_ips"),
        F.countDistinct("host").alias("unique_hosts"),
        F.min("ts").alias("first_ts"),
        F.max("ts").alias("last_ts"),
    )

    return by_ip, by_host, by_status, by_class, totals


def geocode_ips(ips: List[str], pause_s: float = 1.5) -> Dict[str, Dict[str, Any]]:
    """
    Free non-commercial batch geo via ip-api.com (max 100 IPs per request).
    Docs: http://ip-api.com/docs/api:batch
    """
    out: Dict[str, Dict[str, Any]] = {}
    if not ips:
        return out

    batch_size = 100
    for i in range(0, len(ips), batch_size):
        batch = ips[i : i + batch_size]
        payload = json.dumps(
            [{"query": ip, "fields": "status,message,country,countryCode,city,lat,lon,isp,query,org"} for ip in batch]
        ).encode()
        req = urllib.request.Request(
            "http://ip-api.com/batch?fields=status,message,country,countryCode,city,lat,lon,isp,query,org",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                rows = json.loads(resp.read().decode())
            for row in rows:
                if row.get("status") == "success":
                    out[row["query"]] = row
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            print(f"[geo] batch failed: {exc}", file=sys.stderr)
        if i + batch_size < len(ips):
            time.sleep(pause_s)
    return out


def render_html(
    out_path: Path,
    meta: Dict[str, Any],
    ip_rows: List[Dict[str, Any]],
    host_rows: List[Dict[str, Any]],
    status_rows: List[Dict[str, Any]],
    class_rows: List[Dict[str, Any]],
    geo: Dict[str, Dict[str, Any]],
) -> None:
    points = []
    for row in ip_rows:
        ip = row["ip"]
        g = geo.get(ip)
        if not g or g.get("lat") is None:
            continue
        err_ratio = (row.get("errors_4xx5xx") or 0) / max(row.get("requests") or 1, 1)
        points.append(
            {
                "ip": ip,
                "lat": g["lat"],
                "lon": g["lon"],
                "city": g.get("city") or "",
                "country": g.get("country") or "",
                "cc": g.get("countryCode") or "",
                "isp": g.get("isp") or g.get("org") or "",
                "requests": row["requests"],
                "errors": row.get("errors_4xx5xx") or 0,
                "err_ratio": round(err_ratio, 3),
                "hosts": row.get("hosts_hit") or 0,
            }
        )

    # Country rollup for table
    by_country: Dict[str, int] = {}
    for p in points:
        key = p["country"] or "Unknown"
        by_country[key] = by_country.get(key, 0) + p["requests"]
    country_rows = sorted(
        [{"country": k, "requests": v} for k, v in by_country.items()],
        key=lambda x: -x["requests"],
    )[:40]

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Homelab edge map — Caddy × Spark</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    :root {{
      --bg: #0b1020;
      --panel: #121a2f;
      --text: #e8eefc;
      --muted: #8b9bb8;
      --accent: #5b9dff;
      --hot: #ff5b6e;
      --ok: #3dd68c;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; font-family: ui-sans-serif, system-ui, sans-serif;
      background: radial-gradient(1200px 600px at 10% -10%, #1a274a 0%, var(--bg) 55%);
      color: var(--text);
    }}
    header {{
      padding: 1.25rem 1.5rem 0.5rem;
      border-bottom: 1px solid #1e2a48;
    }}
    header h1 {{ margin: 0 0 0.25rem; font-size: 1.35rem; letter-spacing: 0.02em; }}
    header p {{ margin: 0; color: var(--muted); font-size: 0.92rem; }}
    .layout {{
      display: grid;
      grid-template-columns: 1.4fr 1fr;
      gap: 1rem;
      padding: 1rem 1.5rem 1.5rem;
    }}
    @media (max-width: 960px) {{ .layout {{ grid-template-columns: 1fr; }} }}
    #map {{
      height: min(72vh, 720px);
      border-radius: 14px;
      border: 1px solid #243356;
      box-shadow: 0 10px 40px rgba(0,0,0,0.35);
    }}
    .panel {{
      background: var(--panel);
      border: 1px solid #243356;
      border-radius: 14px;
      padding: 1rem 1.1rem;
      max-height: min(72vh, 720px);
      overflow: auto;
    }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 0.6rem;
      margin-bottom: 1rem;
    }}
    .stat {{
      background: #0e162b;
      border-radius: 10px;
      padding: 0.65rem 0.75rem;
      border: 1px solid #1c2a4a;
    }}
    .stat .k {{ color: var(--muted); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; }}
    .stat .v {{ font-size: 1.15rem; font-weight: 650; margin-top: 0.15rem; }}
    h2 {{ font-size: 0.95rem; margin: 1rem 0 0.45rem; color: var(--accent); }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.82rem; }}
    th, td {{ text-align: left; padding: 0.35rem 0.3rem; border-bottom: 1px solid #1c2a4a; }}
    th {{ color: var(--muted); font-weight: 600; }}
    .mono {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }}
    .tag {{
      display: inline-block; padding: 0.1rem 0.4rem; border-radius: 999px;
      font-size: 0.72rem; background: #1a2744; color: var(--muted);
    }}
    footer {{ padding: 0 1.5rem 1.25rem; color: var(--muted); font-size: 0.8rem; }}
  </style>
</head>
<body>
  <header>
    <h1>Caddy edge traffic — Spark analytics</h1>
    <p>Public client IPs from reverse-proxy access logs · generated {meta.get("generated_at", "")} UTC · {meta.get("total_requests", 0):,} requests · {meta.get("unique_ips", 0):,} public IPs · geocoded {len(points)} points</p>
  </header>
  <div class="layout">
    <div id="map"></div>
    <aside class="panel">
      <div class="stats">
        <div class="stat"><div class="k">Requests</div><div class="v">{meta.get("total_requests", 0):,}</div></div>
        <div class="stat"><div class="k">Public IPs</div><div class="v">{meta.get("unique_ips", 0):,}</div></div>
        <div class="stat"><div class="k">Hosts</div><div class="v">{meta.get("unique_hosts", 0):,}</div></div>
        <div class="stat"><div class="k">Map pins</div><div class="v">{len(points):,}</div></div>
      </div>

      <h2>Top countries (by requests)</h2>
      <table>
        <tr><th>Country</th><th>Requests</th></tr>
        {''.join(f"<tr><td>{c['country']}</td><td class='mono'>{c['requests']:,}</td></tr>" for c in country_rows)}
      </table>

      <h2>Path classes</h2>
      <table>
        <tr><th>Class</th><th>Requests</th></tr>
        {''.join(f"<tr><td>{c['path_class']}</td><td class='mono'>{c['requests']:,}</td></tr>" for c in class_rows[:12])}
      </table>

      <h2>Top hosts</h2>
      <table>
        <tr><th>Host</th><th>Req</th><th>IPs</th></tr>
        {''.join(f"<tr><td class='mono'>{(h.get('host') or '—')}</td><td class='mono'>{h['requests']:,}</td><td class='mono'>{h.get('unique_ips', 0):,}</td></tr>" for h in host_rows[:12])}
      </table>

      <h2>HTTP status</h2>
      <table>
        <tr><th>Status</th><th>Requests</th></tr>
        {''.join(f"<tr><td class='mono'>{s.get('status')}</td><td class='mono'>{s['requests']:,}</td></tr>" for s in status_rows[:16])}
      </table>
    </aside>
  </div>
  <footer>
    Spark aggregates on staged Caddy JSON logs · geolocation via ip-api.com (non-commercial) for top talkers only · private RFC1918 clients excluded by default
  </footer>
  <script>
    const points = {json.dumps(points)};
    const map = L.map('map', {{ worldCopyJump: true }}).setView([20, 0], 2);
    L.tileLayer('https://{{s}}.basemaps.cartocdn.com/dark_all/{{z}}/{{x}}/{{y}}{{r}}.png', {{
      attribution: '&copy; OpenStreetMap &copy; CARTO',
      maxZoom: 18
    }}).addTo(map);

    // Tiny pins: slight log scale, capped small so the map stays readable
    function radiusFor(req) {{
      return Math.max(2, Math.min(5, 1.6 + Math.log10(req + 1) * 1.1));
    }}
    function colorFor(errRatio) {{
      if (errRatio >= 0.5) return '#ff5b6e';
      if (errRatio >= 0.2) return '#ffb020';
      return '#5b9dff';
    }}

    const layer = L.layerGroup().addTo(map);
    points.forEach(p => {{
      const m = L.circleMarker([p.lat, p.lon], {{
        radius: radiusFor(p.requests),
        color: colorFor(p.err_ratio),
        fillColor: colorFor(p.err_ratio),
        fillOpacity: 0.75,
        weight: 0.6,
        opacity: 0.9
      }}).bindPopup(
        `<div style="min-width:190px">
          <strong class="mono">${{p.ip}}</strong><br/>
          ${{p.city ? p.city + ', ' : ''}}${{p.country}} <span class="tag">${{p.cc}}</span><br/>
          <span class="tag">${{p.isp}}</span><br/>
          requests: <b>${{p.requests.toLocaleString()}}</b><br/>
          4xx/5xx: <b>${{p.errors.toLocaleString()}}</b> (${{Math.round(p.err_ratio*100)}}%)<br/>
          hosts hit: <b>${{p.hosts}}</b>
        </div>`
      );
      layer.addLayer(m);
    }});
    if (points.length) {{
      map.fitBounds(layer.getBounds().pad(0.2));
    }}
  </script>
</body>
</html>
"""
    out_path.write_text(html, encoding="utf-8")


def rows_as_dicts(df, limit: Optional[int] = None) -> List[Dict[str, Any]]:
    d = df if limit is None else df.limit(limit)
    return [r.asDict(recursive=True) for r in d.collect()]


def main() -> int:
    args = parse_args()
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    t0 = time.time()
    spark = build_spark("Caddy-Geo-Map")
    spark.sparkContext.setLogLevel("WARN")

    print(f"[spark] reading logs from {args.input}")
    events = load_events(spark, args.input, args.partitions)
    events = filter_scope(events, args.include_private)
    # Cache for multiple aggregations
    events = events.cache()
    n = events.count()
    print(f"[spark] events in scope: {n:,}")

    by_ip, by_host, by_status, by_class, totals = aggregate(events)
    total_row = rows_as_dicts(totals)[0] if n else {
        "total_requests": 0,
        "unique_ips": 0,
        "unique_hosts": 0,
        "first_ts": None,
        "last_ts": None,
    }

    # Collect enough IPs for threshold-based geocode (cap hard at 50k for safety)
    collect_n = max(args.top_n, 5000) if args.min_requests > 0 else max(args.top_n, 500)
    collect_n = min(collect_n, 50000)
    ip_rows = rows_as_dicts(by_ip, limit=collect_n)
    host_rows = rows_as_dicts(by_host, limit=50)
    status_rows = rows_as_dicts(by_status)
    class_rows = rows_as_dicts(by_class)

    # Persist Spark outputs
    by_ip.coalesce(1).write.mode("overwrite").option("header", True).csv(
        str(out_dir / "by_ip_csv")
    )
    by_host.coalesce(1).write.mode("overwrite").option("header", True).csv(
        str(out_dir / "by_host_csv")
    )
    summary_path = out_dir / "summary.json"
    summary = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        "input": args.input,
        "spark_seconds": None,
        "min_requests": args.min_requests,
        "top_n": args.top_n,
        **total_row,
        "top_ips": ip_rows[:50],
        "top_hosts": host_rows[:30],
        "status": status_rows,
        "path_classes": class_rows,
    }

    geo: Dict[str, Dict[str, Any]] = {}
    geo_path = out_dir / "geocode.json"
    if args.reuse_geo and geo_path.exists():
        try:
            geo = json.loads(geo_path.read_text(encoding="utf-8"))
            print(f"[geo] reused {len(geo)} entries from {geo_path}")
        except (json.JSONDecodeError, OSError) as e:
            print(f"[geo] reuse failed: {e}", file=sys.stderr)
            geo = {}

    if not args.skip_geo and ip_rows:
        if args.min_requests > 0:
            candidates = [
                r for r in ip_rows if int(r.get("requests") or 0) >= args.min_requests
            ]
            candidates = candidates[: args.top_n]
            print(
                f"[geo] threshold: requests>={args.min_requests} → "
                f"{len(candidates)} IPs (cap top_n={args.top_n})"
            )
        else:
            candidates = ip_rows[: args.top_n]
            print(f"[geo] top-n mode: {len(candidates)} IPs")

        need = [r["ip"] for r in candidates if r.get("ip") and r["ip"] not in geo]
        print(f"[geo] need fetch {len(need)} (already cached {len(candidates) - len(need)})")
        if need:
            fetched = geocode_ips(need)
            geo.update(fetched)
            print(f"[geo] resolved {len(fetched)} / {len(need)} new")
        (out_dir / "geocode.json").write_text(json.dumps(geo, indent=2), encoding="utf-8")

        # Country rollup for summary (request-weighted, geocoded set only)
        by_country: Dict[str, int] = {}
        for r in candidates:
            g = geo.get(r["ip"]) or {}
            if g.get("status") == "success" or g.get("country"):
                c = g.get("country") or "Unknown"
                by_country[c] = by_country.get(c, 0) + int(r.get("requests") or 0)
        summary["countries_by_requests"] = sorted(
            [{"country": k, "requests": v} for k, v in by_country.items()],
            key=lambda x: -x["requests"],
        )
        # Uniform per-country rollup (no special-case country)
        top_countries = summary["countries_by_requests"][:12]
        if top_countries:
            parts = [f"{c['country']}: {c['requests']:,}" for c in top_countries]
            print(f"[geo] top countries (geocoded set): {'; '.join(parts)}")
        else:
            print("[geo] no countries in geocoded set")

    elapsed = time.time() - t0
    summary["spark_seconds"] = round(elapsed, 2)
    summary_path.write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    map_path = out_dir / "geo_map.html"
    render_html(
        map_path,
        meta=summary,
        ip_rows=ip_rows,
        host_rows=host_rows,
        status_rows=status_rows,
        class_rows=class_rows,
        geo=geo,
    )

    spark.stop()
    print(f"[done] {elapsed:.1f}s")
    print(f"  map:     {map_path}")
    print(f"  summary: {summary_path}")
    print(f"  by_ip:   {out_dir / 'by_ip_csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
