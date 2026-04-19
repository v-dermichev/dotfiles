"""Persistent browser inspection server for AI agents.

Start once, send HTTP requests to navigate pages, get source, take screenshots.
Avoids restarting Chrome for each inspection — faster and avoids rate limiting.

Usage:
    .venv/bin/python -m framework.tools.inspect_server
    .venv/bin/python -m framework.tools.inspect_server --port 9222 --no-headless

Endpoints:
    POST /navigate         {"url": "https://..."}  → navigate to URL, return page source
    GET  /source           → current page source (HTML)
    GET  /screenshot       → screenshot as PNG (binary)
    GET  /url              → current URL (text)
    POST /execute          {"script": "return document.title"}  → execute JS, return result
    POST /click            {"selector": "button.submit"}  → click element by CSS selector
    POST /type             {"selector": "input#q", "text": "query"}  → type into element
    GET  /title            → page title (text)
    POST /elements         {"selector": ".product-card"}  → get list of elements' text/attrs
    POST /dismiss_popup    {"selector": "button.close"}  → click if element exists
    POST /quit             → shut down the server and browser
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Any

import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


def _detect_chrome_version() -> int | None:
    for binary in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        path = shutil.which(binary)
        if path is None:
            continue
        try:
            output = subprocess.check_output([path, "--version"], text=True, timeout=5)
        except (subprocess.SubprocessError, OSError):
            continue
        import re
        match = re.search(r"(\d+)", output)
        if match:
            return int(match.group(1))
    return None


class InspectHandler(BaseHTTPRequestHandler):
    driver: uc.Chrome
    server_instance: HTTPServer

    def log_message(self, format: str, *args: Any) -> None:
        pass

    def _send_json(self, data: Any, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, text: str, status: int = 200) -> None:
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_binary(self, data: bytes, content_type: str, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw)

    def do_GET(self) -> None:
        try:
            if self.path == "/source":
                self._send_text(self.driver.page_source)
            elif self.path == "/screenshot":
                png = self.driver.get_screenshot_as_png()
                self._send_binary(png, "image/png")
            elif self.path == "/url":
                self._send_text(self.driver.current_url)
            elif self.path == "/title":
                self._send_text(self.driver.title)
            elif self.path == "/quit":
                self._send_json({"status": "shutting down"})
                threading.Thread(target=self.server_instance.shutdown, daemon=True).start()
            else:
                self._send_json({"error": f"Unknown endpoint: {self.path}"}, 404)
        except Exception as e:
            self._send_json({"error": str(e)}, 500)

    def do_POST(self) -> None:
        try:
            body = self._read_body()

            if self.path == "/navigate":
                url = body.get("url", "")
                self.driver.get(url)
                WebDriverWait(self.driver, 30).until(
                    lambda d: d.execute_script("return document.readyState") == "complete"
                )
                self._send_json({
                    "url": self.driver.current_url,
                    "title": self.driver.title,
                })

            elif self.path == "/execute":
                script = body.get("script", "")
                result = self.driver.execute_script(script)
                self._send_json({"result": result})

            elif self.path == "/click":
                selector = body.get("selector", "")
                timeout = body.get("timeout", 10)
                element = WebDriverWait(self.driver, timeout).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, selector))
                )
                element.click()
                self._send_json({"clicked": selector})

            elif self.path == "/type":
                selector = body.get("selector", "")
                text = body.get("text", "")
                submit = body.get("submit", False)
                timeout = body.get("timeout", 10)
                element = WebDriverWait(self.driver, timeout).until(
                    EC.visibility_of_element_located((By.CSS_SELECTOR, selector))
                )
                element.clear()
                element.send_keys(text)
                if submit:
                    element.send_keys(Keys.RETURN)
                self._send_json({"typed": text, "selector": selector})

            elif self.path == "/elements":
                selector = body.get("selector", "")
                attr = body.get("attr", None)
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                results = []
                for el in elements:
                    item = {"text": el.text, "tag": el.tag_name}
                    if attr:
                        item["attr"] = el.get_attribute(attr)
                    results.append(item)
                self._send_json({"count": len(results), "elements": results})

            elif self.path == "/dismiss_popup":
                selector = body.get("selector", "")
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                dismissed = False
                if elements and elements[0].is_displayed():
                    elements[0].click()
                    dismissed = True
                self._send_json({"dismissed": dismissed, "selector": selector})

            elif self.path == "/quit":
                self._send_json({"status": "shutting down"})
                threading.Thread(target=self.server_instance.shutdown, daemon=True).start()

            else:
                self._send_json({"error": f"Unknown endpoint: {self.path}"}, 404)

        except Exception as e:
            self._send_json({"error": str(e)}, 500)


def _is_windows() -> bool:
    import sys
    return sys.platform == "win32"


def _windows_has_monitor() -> bool:
    try:
        import ctypes
        user32 = ctypes.windll.user32
        return user32.GetSystemMetrics(0) > 0
    except Exception:
        return False


def _start_xvfb() -> subprocess.Popen | None:
    import shutil
    if not shutil.which("Xvfb"):
        return None
    try:
        proc = subprocess.Popen(
            ["Xvfb", ":99", "-screen", "0", "1920x1080x24", "-nolisten", "tcp"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        import os, time
        os.environ["DISPLAY"] = ":99"
        time.sleep(1)
        print("Xvfb started on :99")
        return proc
    except FileNotFoundError:
        return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Browser inspection server")
    parser.add_argument("--port", type=int, default=9222)
    parser.add_argument("--headful", action="store_true", help="Force headful mode (opens browser window or uses Xvfb)")
    parser.add_argument("--window-size", default="1920,1080")
    args = parser.parse_args()

    xvfb_proc = None
    use_headless = not args.headful
    mode = "headless"

    if args.headful:
        if _is_windows():
            if _windows_has_monitor():
                mode = "headful"
            else:
                mode = "headful"
        else:
            import os
            has_display = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))
            if has_display:
                mode = "headful"
            else:
                xvfb_proc = _start_xvfb()
                if xvfb_proc:
                    mode = "xvfb"
                else:
                    print("No display and Xvfb not available, falling back to headless")
                    use_headless = True

    options = uc.ChromeOptions()
    if use_headless:
        options.add_argument("--headless=new")
    if not _is_windows():
        options.add_argument("--no-sandbox")
    options.add_argument(f"--window-size={args.window_size}")

    version = _detect_chrome_version()
    print(f"Starting browser (Chrome {version}, mode={mode})")
    driver = uc.Chrome(options=options, version_main=version)
    print(f"Browser started")

    InspectHandler.driver = driver

    server = HTTPServer(("127.0.0.1", args.port), InspectHandler)
    InspectHandler.server_instance = server

    print(f"Inspection server listening on http://127.0.0.1:{args.port}")
    print(f"Endpoints: /navigate, /source, /screenshot, /url, /title, /execute, /click, /type, /elements, /dismiss_popup, /quit")

    try:
        server.serve_forever()
    finally:
        driver.quit()
        print("Browser closed")
        if xvfb_proc:
            xvfb_proc.terminate()
            xvfb_proc.wait()
            print("Xvfb stopped")


if __name__ == "__main__":
    main()
