#!/usr/bin/env python3
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime, timedelta

# Configuration
PORT = 9002
F2B_LOG_FILE = "/var/log/fail2ban.log"
CS_LOG_FILE = "/var/log/crowdsec.log"
DEDUPE_WINDOW = timedelta(minutes=2) # Time window to consider bans "duplicate"

# --- REGEX PATTERNS ---

# Fail2Ban Pattern
F2B_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),.*?"     # 1. Timestamp
    r"\[([^\]]+)\]\s+"                                # 2. Jail Name
    r"(Ban)\s+"                                       # 4. Action (Banned, Unbanned, Found, Ignore)
    r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"           # 4. IP Address
)

# CrowdSec Pattern (Targeting "Scenario by ip ... ban")
CS_PATTERN = re.compile(
    r'time="([^"]+)".*?'                              # 1. Timestamp
    r'msg=".*?'                                       # Skip start of msg
    r'(?:crowdsecurity/)?([^\s]+)\s+'                 # 2. Scenario
    r'by\s+ip\s+'                                     # Anchor text
    r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*?'        # 3. IP Address
    r'ban'                                            # Ensure it includes "ban"
)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        events = []
        # We need a lookup cache to store CrowdSec bans: { '1.2.3.4': [dt1, dt2] }
        cs_cache = {} 
        
        cutoff_time = datetime.now() - timedelta(days=1)
        
        # --- 1. PARSE CROWDSEC FIRST ---
        # We parse CS first so we know what to skip in F2B
        if os.path.exists(CS_LOG_FILE):
            try:
                with open(CS_LOG_FILE, 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f:
                        match = CS_PATTERN.search(line)
                        if match:
                            ts_str, scenario, ip = match.groups()
                            try:
                                clean_ts = ts_str.split('.')[0].replace('T', ' ').replace('Z', '')
                                dt = datetime.strptime(clean_ts, "%Y-%m-%d %H:%M:%S")
                                
                                if dt > cutoff_time:
                                    # Add to display list
                                    events.append({
                                        'dt': dt,
                                        'ip': ip,
                                        'jail': scenario,
                                        'source': 'CS',
                                        'color': '#d63384'
                                    })
                                    
                                    # Add to Cache for Deduplication
                                    if ip not in cs_cache:
                                        cs_cache[ip] = []
                                    cs_cache[ip].append(dt)

                            except ValueError: continue
            except Exception as e:
                print(f"Error reading CS log: {e}")

        # --- 2. PARSE FAIL2BAN ---
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
                                    # --- DEDUPLICATION LOGIC ---
                                    # Check if this IP was banned by CrowdSec roughly at the same time
                                    is_duplicate = False
                                    if ip in cs_cache:
                                        for cs_dt in cs_cache[ip]:
                                            # If diff is less than 2 mins, assume it's the same event
                                            if abs(dt - cs_dt) < DEDUPE_WINDOW:
                                                is_duplicate = True
                                                break
                                    
                                    if is_duplicate:
                                        continue
                                    # ---------------------------

                                    events.append({
                                        'dt': dt,
                                        'ip': ip,
                                        'jail': jail,
                                        'source': 'F2B',
                                        'color': '#ff4444'
                                    })
                            except ValueError: continue
            except Exception as e:
                print(f"Error reading F2B log: {e}")

        # Sort events by time (Newest first)
        events.sort(key=lambda x: x['dt'], reverse=True)

        # Generate Rows
        rows = []
        if not events:
            rows.append("<tr><td colspan='4'>No bans found in the last 24h</td></tr>")
        else:
            for e in events:
                rows.append(f"""
                <tr>
                    <td>{e['dt'].strftime('%Y-%m-%d %H:%M:%S')}</td>
                    <td>{e['ip']}</td>
                    <td><span class="badge {e['source']}">{e['source']}</span> {e['jail']}</td>
                    <td style="color:{e['color']}; font-weight:bold;">Banned</td>
                </tr>
                """)

        html_content = self.get_html("".join(rows))
        self.wfile.write(html_content.encode('utf-8'))

    def get_html(self, table_rows):
        return f"""
        <html>
          <head>
            <meta http-equiv="refresh" content="60">
            <style>
              body {{ 
                  font-family: monospace; 
                  padding: 1rem; 
                  background: #121212; 
                  color: #eee; 
                  font-size: 11px;
              }}
              table {{ 
                  border-collapse: collapse; 
                  width: 100%; 
                  max-width: 900px; 
                  font-size: 11px;
              }}
              th, td {{ border: 1px solid #444; padding: 8px; text-align: left; }}
              th {{ background-color: #333; }}
              tr:nth-child(even) {{ background-color: #1e1e1e; }}
              
              .badge {{
                  padding: 2px 5px;
                  border-radius: 3px;
                  font-size: 9px;
                  font-weight: bold;
                  margin-right: 5px;
                  color: #fff;
              }}
              .F2B {{ background-color: #c0392b; }}
              .CS  {{ background-color: #8e44ad; }}
            </style>
            <title>Intrusion Monitor</title>
          </head>
          <body>
            <table>
              <thead>
                <tr>
                    <th>Timestamp</th>
                    <th>IP Address</th>
                    <th>Jail / Scenario</th>
                    <th>Status</th>
                </tr>
              </thead>
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