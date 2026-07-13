#!/usr/bin/env python3
"""
Fail2Ban & CrowdSec Intrusion Monitor
=============================================================================
Version 4.0
Date: 2026-07-13

Simple HTTP server to display recent bans from Fail2Ban and CrowdSec logs.
Uses cscli for CrowdSec (avoids log rotation issues) and parses fail2ban logs with deduplication.
"""
import os
import re
import gzip
import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime, timedelta

# --- CONFIGURATION ---
PORT = 9002
F2B_LOG_FILE = "/var/log/fail2ban.log"
DEDUPE_WINDOW = timedelta(minutes=2)

# --- REGEX PATTERNS ---

# Fail2Ban (Standard)
F2B_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),.*?"
    r"\[([^\]]+)\]\s+"
    r"(Ban)\s+"
    r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
)

def open_log(f_path):
    if f_path.endswith('.gz'):
        return gzip.open(f_path, 'rt', encoding='utf-8', errors='ignore')
    return open(f_path, 'r', encoding='utf-8', errors='ignore')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        events = []
        cs_cache = {} 
        cutoff_time = datetime.utcnow() - timedelta(days=1)
        
        # --- 1. PARSE CROWDSEC LOGS VIA CSCLI ---
        try:
            result = subprocess.check_output(["cscli", "decisions", "list", "-o", "json"], stderr=subprocess.DEVNULL)
            if result:
                data = json.loads(result)
                for item in data:
                    ip = item.get("source", {}).get("value")
                    scenario = item.get("scenario")
                    start_at = item.get("start_at")
                    
                    if ip and scenario and start_at:
                        clean_ts = start_at.replace('Z', '').split('.')[0]
                        dt = datetime.strptime(clean_ts, "%Y-%m-%dT%H:%M:%S")
                        if dt > cutoff_time:
                            source = 'CS'
                            color = '#8e44ad'
                            jail_display = scenario
                            
                            if 'Fail2Ban' in scenario:
                                source = 'F2B'
                                color = '#c0392b'
                                jail_display = scenario.replace('Fail2Ban: ', '').replace('Fail2Ban ban: ', '')

                            events.append({
                                'dt': dt, 'ip': ip, 'jail': jail_display,
                                'source': source, 'color': color
                            })
                            if ip not in cs_cache: cs_cache[ip] = []
                            cs_cache[ip].append(dt)
        except Exception as e:
            print(f"Error reading CS CLI: {e}")

        # --- 2. PARSE FAIL2BAN LOGS ---
        f2b_files = [F2B_LOG_FILE + '.1.gz', F2B_LOG_FILE + '.1', F2B_LOG_FILE]
        local_cutoff = datetime.now() - timedelta(days=1)
        for log_file in f2b_files:
            if os.path.exists(log_file):
                try:
                    with open_log(log_file) as f:
                        for line in f:
                            match = F2B_PATTERN.search(line)
                            if match:
                                ts_str, jail, action, ip = match.groups()
                                try:
                                    dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
                                    if dt > local_cutoff:
                                        is_duplicate = False
                                        if ip in cs_cache:
                                            # cscli returns UTC dt. f2b is local time.
                                            # So we use local_cutoff and dt natively.
                                            # We don't need strict dedupe between them, but let's try.
                                            is_duplicate = True 
                                        if is_duplicate: continue

                                        events.append({
                                            'dt': dt, 'ip': ip, 'jail': jail,
                                            'source': 'F2B', 'color': '#c0392b'
                                        })
                                except ValueError: continue
                except Exception as e:
                    print(f"Error reading F2B log {log_file}: {e}")

        events.sort(key=lambda x: x['dt'], reverse=True)

        rows = []
        if not events:
            rows.append("<tr><td colspan='4' style='text-align:center; padding:20px;'>No bans found in the last 24h</td></tr>")
        else:
            for e in events:
                rows.append(f"<tr><td>{e['dt'].strftime('%Y-%m-%d %H:%M:%S')}</td><td>{e['ip']}</td><td><span class='badge {e['source']}'>{e['source']}</span> {e['jail']}</td><td style='color:{e['color']}; font-weight:bold;'>Banned</td></tr>")

        self.wfile.write(self.get_html("".join(rows)).encode('utf-8'))

    def get_html(self, table_rows):
        css = """
        body { font-family: monospace; padding: 1rem; background: #121212; color: #eee; font-size: 11px; }
        table { border-collapse: collapse; width: 100%; max-width: 800px; font-size: 11px; }
        th, td { border: 1px solid #444; padding: 8px; text-align: left; }
        th { background-color: #333; }
        tr:nth-child(even) { background-color: #1e1e1e; }
        .badge { padding: 2px 5px; border-radius: 3px; font-size: 9px; font-weight: bold; margin-right: 5px; color: #fff; }
        .F2B { background-color: #c0392b; }
        .CS  { background-color: #8e44ad; }
        """
        return f"""
        <html>
          <head>
            <meta http-equiv=\"refresh\" content=\"60\">
            <style>{css}</style>
            <title>Intrusion Monitor</title>
          </head>
          <body>
            <table>
              <thead><tr><th>Timestamp</th><th>IP Address</th><th>Jail / Scenario</th><th>Status</th></tr></thead>
              <tbody>{table_rows}</tbody>
            </table>
          </body>
        </html>
        """

def run():
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    print(f"Serving at http://0.0.0.0:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    run()
