#!/usr/bin/env python3
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime, timedelta

# Configuration
PORT = 9002
LOG_FILE = "/var/log/fail2ban.log"

# REGEX EXPLAINED:
# 1. Matches Timestamp at start
# 2. Looks for Jail Name (authcode or sensitivepaths, handling plural 's' optionally)
# 3. Captures the Action keyword ("Ban" OR "Found")
# 4. Captures the IP Address
LOG_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),.*?"     # 1. Timestamp & Noise
    r"\[([^\]]+)\]\s+"                                # 3. Jail Name
    r"(Ban)\s+"                                       # 4. Action (Banned, Unbanned, Found, Ignore)
    r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"           # 5. IP Address
)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        rows = []
        cutoff_time = datetime.now() - timedelta(days=1)
        
        try:
            with open(LOG_FILE, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    match = LOG_PATTERN.search(line)
                    if match:
                        timestamp_str, jail, action, ip = match.groups()
                        try:
                            log_time = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
                            
                            if log_time > cutoff_time:
                                # Color code based on action
                                if action == "Ban":
                                    color = "#ff4444" # Red
                                    status = "Banned"
                                elif action == "Unban":
                                    color = "#44ff44" # Green (Bright Green)
                                    status = "Unbanned"
                                else:
                                    color = "#ffbb33" # Orange
                                    status = "Attempt"

                                # Create the row
                                row_html = f"""
                                <tr>
                                    <td>{timestamp_str}</td>
                                    <td>{ip}</td>
                                    <td>{jail}</td>
                                    <td style="color:{color}; font-weight:bold;">{status}</td>
                                </tr>
                                """
                                rows.insert(0, row_html)
                        except ValueError:
                            continue
        except FileNotFoundError:
            rows.append("<tr><td colspan='4'>Log file not found</td></tr>")

        if not rows:
             rows.append("<tr><td colspan='4'>No activity found in the last 24h</td></tr>")

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
              h2 {{ border-bottom: 1px solid #444; padding-bottom: 10px; }}
            </style>
            <title>Fail2Ban Monitor</title>
          </head>
          <body>
            <table>
              <thead>
                <tr>
                    <th>Timestamp</th>
                    <th>IP Address</th>
                    <th>Jail</th>
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