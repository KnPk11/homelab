#!/usr/bin/env python3
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
import html

PORT = 9002

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        # Remove any X-Frame-Options headers if they were being added by some library or framework.
        # It's better to not send it at all if you want to allow embedding.
        self.end_headers()

        # Run your bash script and get output lines
        output = subprocess.run(
            ['/bin/bash', '/usr/local/bin/fail2ban_log.sh'],
            capture_output=True, text=True).stdout.strip()

        # Escape output for safety
        escaped_output = html.escape(output)

        # Build HTML table rows from each line "IP - timestamp"
        rows = ""
        for line in escaped_output.splitlines():
            if " - " in line:
                ip, ts = line.split(" - ", 1)
                rows += f"<tr><td>{ip}</td><td>{ts}</td></tr>"

        html_page = f"""
        <html>
          <head>
            <style>
              body {{
                font-family: Arial, sans-serif;
                padding: 0.5rem;
                background: #121212;
                color: #eee;
                font-size: 0.75rem;
              }}
              table {{
                border-collapse: collapse;
                width: 100%;
                font-size: 0.75rem;
              }}
              th, td {{
                border: 1px solid #444;
                padding: 4px 6px;
                text-align: left;
              }}
              th {{
                background-color: #222;
              }}
              h2 {{
                font-size: 1rem;
                margin-bottom: 0.5rem;
              }}
            </style>
            <title>Fail2Ban Caddy Bans</title>
          </head>
          <body>
            <table>
              <thead><tr><th>Timestamp</th><th>IP Address</th></tr></thead>
              <tbody>
                {rows}
              </tbody>
            </table>
          </body>
        </html>
        """

        self.wfile.write(html_page.encode('utf-8'))

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

def run():
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    print(f"Serving fail2ban bans at http://0.0.0.0:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    run()