#!/usr/bin/env python3
"""
hard-tools: lib/raw_sink.py
Atomic Frame Buffer Sink for UVC Webcam Gadget.
Reads raw YUYV frames from standard input and updates /dev/shm/uvc_frame.raw atomically.
"""

import os
import sys
import time

FRAME_SIZE = 640 * 360 * 2  # 460800 bytes
TARGET_PATH = "/dev/shm/uvc_frame.raw"
TMP_PATH = "/dev/shm/uvc_frame.tmp"

# Fallback to /tmp if /dev/shm is unavailable
if not os.path.exists("/dev/shm"):
    TARGET_PATH = "/tmp/uvc_frame.raw"
    TMP_PATH = "/tmp/uvc_frame.tmp"

def main():
    stdin_fd = sys.stdin.fileno()
    while True:
        frame_data = bytearray()
        while len(frame_data) < FRAME_SIZE:
            chunk = os.read(stdin_fd, FRAME_SIZE - len(frame_data))
            if not chunk:
                return  # End of stream
            frame_data.extend(chunk)

        try:
            with open(TMP_PATH, "wb") as f:
                f.write(frame_data)
            os.replace(TMP_PATH, TARGET_PATH)
        except Exception:
            pass

if __name__ == "__main__":
    main()
