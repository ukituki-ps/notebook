#!/usr/bin/env python3
"""mobile-runner — HTTP-раннер device-lab на хосте, где физически висят устройства.

Nexus (mobile_run) делегирует сюда исполнение: Nexus хранит реестр/аренду, а
adb/Maestro живут на dev-хосте (аналог: стенды в Nexus, docker — на dev-хосте).

Endpoints (POST, JSON):
  /doctor                 → tools/mobile-device.sh doctor
  /run {device,flow?,url?,out?} → test|url
  /screenshot {device,out}      → shot

Защита: если задан MOBILE_RUNNER_TOKEN, требуется заголовок X-Mobile-Token.
Конфиг: MOBILE_KIT (путь к kit, по умолчанию /home/ukituki/archkit),
        MOBILE_RUNNER_ADDR (по умолчанию 0.0.0.0:8099).
"""
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.environ.get("MOBILE_KIT", "/home/ukituki/archkit")
SCRIPT = os.path.join(ROOT, "tools", "mobile-device.sh")
TOKEN = os.environ.get("MOBILE_RUNNER_TOKEN", "")
ADDR = os.environ.get("MOBILE_RUNNER_ADDR", "0.0.0.0:8099")


def run(args, timeout=900):
    try:
        p = subprocess.run(["bash", SCRIPT, *args], capture_output=True, text=True, timeout=timeout)
        return {"rc": p.returncode, "stdout": p.stdout[-8000:], "stderr": p.stderr[-4000:]}
    except subprocess.TimeoutExpired:
        return {"rc": 124, "stdout": "", "stderr": f"timeout after {timeout}s"}


class H(BaseHTTPRequestHandler):
    def _reply(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._reply(200, {"service": "mobile-runner", "kit": ROOT, "auth": bool(TOKEN)})

    def do_POST(self):
        if TOKEN and self.headers.get("X-Mobile-Token") != TOKEN:
            self._reply(401, {"ok": False, "error": "bad token"})
            return
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            self._reply(400, {"ok": False, "error": "bad json"})
            return
        action = self.path.strip("/").split("/")[0]
        dev = str(body.get("device", ""))
        out = str(body.get("out", ""))
        if action == "doctor":
            res = run(["doctor"])
        elif action == "run":
            if body.get("flow"):
                args = ["test", dev, str(body["flow"])] + (["--out", out] if out else [])
                res = run(args)
            elif body.get("url"):
                args = ["url", dev, str(body["url"])] + (["--out", out] if out else [])
                res = run(args)
            else:
                res = {"rc": 2, "stdout": "", "stderr": "flow or url required"}
        elif action == "screenshot":
            res = run(["shot", dev, out or f"/tmp/{dev}.png"])
        else:
            res = {"rc": 2, "stdout": "", "stderr": f"unknown action {action!r}"}
        self._reply(200, {"ok": res["rc"] == 0, **res})

    def log_message(self, fmt, *a):
        print("mobile-runner: " + (fmt % a), flush=True)


if __name__ == "__main__":
    host, port = ADDR.rsplit(":", 1)
    print(f"mobile-runner on {ADDR} (kit={ROOT}, auth={bool(TOKEN)})", flush=True)
    ThreadingHTTPServer((host, int(port)), H).serve_forever()
