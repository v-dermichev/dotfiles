#!/usr/bin/env python3
"""Native messaging host — receives URLs from browser extension and opens via xdg-open."""
import json
import struct
import subprocess
import sys

def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) < 4:
        sys.exit(0)
    length = struct.unpack('@I', raw_length)[0]
    data = sys.stdin.buffer.read(length)
    return json.loads(data)

def send_message(msg):
    data = json.dumps(msg).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('@I', len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()

import os
import traceback

log_file = '/tmp/native-msg-host.log'

msg = read_message()
url = msg.get('url', '')

with open(log_file, 'a') as f:
    f.write(f"Received: {msg}\n")
    f.write(f"URL: {url}\n")
    f.write(f"DISPLAY: {os.environ.get('DISPLAY', 'unset')}\n")
    f.write(f"WAYLAND: {os.environ.get('WAYLAND_DISPLAY', 'unset')}\n")

if url:
    try:
        result = subprocess.run(['xdg-open', url], capture_output=True, text=True, timeout=5)
        with open(log_file, 'a') as f:
            f.write(f"xdg-open exit: {result.returncode}\n")
            f.write(f"stdout: {result.stdout}\n")
            f.write(f"stderr: {result.stderr}\n")
        send_message({'status': 'ok'})
    except Exception as e:
        with open(log_file, 'a') as f:
            f.write(f"Error: {traceback.format_exc()}\n")
        send_message({'status': 'error', 'message': str(e)})
