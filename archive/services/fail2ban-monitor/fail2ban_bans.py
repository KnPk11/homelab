#!/usr/bin/env python3
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime, timedelta

# --- CONFIGURATION ---
PORT = 9002
F2B_LOG_FILE = "/var/log/fail2ban.log"
CS_LOG_FILE = "/var/log/crowdsec.log"
DEDUPE_WINDOW = timedelta(minutes=2)

# --- REGEX PATTERNS ---

# Fail2Ban (Standard)
F2B_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),.*?"
    r"\[([^\]]+)\]\s+"
    r"(Ban)\s+"
    r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
)

# CrowdSec (Matches v1.4+ logs)
# Matches: time="07-02-2026 12:38:11" ... msg="ip 1.2.3.4 performed '...' ... : ban"
CS_PATTERN = re.compile(
    r'time="([^"]+)".*?'                           # 1. Timestamp
    r'msg="ip\s+'                                  # Anchor
    r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+'     # 2. IP Address
    r'performed\s+'                                # Anchor
    r'\'([^\']+)\'.*?'                             # 3. Scenario
    r':\s+ban'                                     # Ensure it is a ban
)

# CrowdSec (Legacy / Fallback)
CS_PATTERN_LEGACY = re.compile(
    r'time="([^"]+)".*?' 
    r'msg=".*?' 
    r'(?:crowdsecurity/)?([^\s]+)\s+' 
    r'by\s+ip\s+' 
    r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*?' 
    r'ban' 
)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        events = []
        cs_cache = {} 
        cutoff_time = datetime.now() - timedelta(days=1)
        
        # --- 1. PARSE CROWDSEC LOGS ---
        if os.path.exists(CS_LOG_FILE):
            try:
                with open(CS_LOG_FILE, 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f:
                        # Try Modern Pattern
                        match = CS_PATTERN.search(line)
                        if match:
                            ts_str, ip, scenario = match.groups()
                        else:
                            # Try Legacy Pattern
                            match = CS_PATTERN_LEGACY.search(line)
                            if match:
                                ts_str, scenario, ip = match.groups()
                            else:
                                continue

                        # --- DATE PARSING FIX ---
                        # Clean timestamp (remove T/Z if present)
                        clean_ts = ts_str.split('.')[0].replace('T', ' ').replace('Z', '')
                        
                        dt = None
                        # Try the format seen in your logs (DD-MM-YYYY)
                        try:
                            dt = datetime.strptime(clean_ts, "%d-%m-%Y %H:%M:%S")
                        except ValueError:
                            # Try ISO format (YYYY-MM-DD) just in case
                            try:
                                dt = datetime.strptime(clean_ts, "%Y-%m-%d %H:%M:%S")
                            except ValueError:
                                continue # Skip if no date format matches

                        if dt and dt > cutoff_time:
                            events.append({
                                'dt': dt, 'ip': ip, 'jail': scenario,
                                'source': 'CS', 'color': '#d63384'
                            })
                            if ip not in cs_cache: cs_cache[ip] = []
                            cs_cache[ip].append(dt)

            except Exception as e:
                print(f"Error reading CS log: {e}")

        # --- 2. PARSE FAIL2BAN LOGS ---
        if os.path.exists(F2B_LOG_FILE):
            try:
                with open(F2B_LOG_FILE, 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f:
                        match = F2B_PATTERN.search(line)
                        if match:
                            ts_str, jail, action, ip = match.groups()
                            try:
                                dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
                                if dt > cutoff_time:
                                    # Deduplication
                                    is_duplicate = False
                                    if ip in cs_cache:
                                        for cs_dt in cs_cache[ip]:
                                            if abs(dt - cs_dt) < DEDUPE_WINDOW:
                                                is_duplicate = True
                                                break
                                    if is_duplicate: continue

                                    events.append({
                                        'dt': dt, 'ip': ip, 'jail': jail,
                                        'source': 'F2B', 'color': '#ff4444'
                                    })
                            except ValueError: continue
            except Exception as e:
                print(f"Error reading F2B log: {e}")

        events.sort(key=lambda x: x['dt'], reverse=True)

        # Generate HTML Rows
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
            <meta http-equiv="refresh" content="60">
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