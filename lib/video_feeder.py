#!/usr/bin/env python3
"""
hard-tools: lib/video_feeder.py
High-Performance Atomic Frame Feeder for UVC Webcam Gadget.
"""

import sys
import os
import time
import subprocess

FRAME_SIZE = 640 * 360 * 2  # 460800 bytes
TARGET_PATH = "/dev/shm/uvc_frame.raw"
TMP_PATH = "/dev/shm/uvc_frame.tmp"

if not os.path.exists("/dev/shm"):
    TARGET_PATH = "/tmp/uvc_frame.raw"
    TMP_PATH = "/tmp/uvc_frame.tmp"

def main():
    if len(sys.argv) < 2:
        print("Usage: video_feeder.py <video_file | camera | test>")
        sys.exit(1)

    mode = sys.argv[1]

    if mode == "test":
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-re", "-f", "lavfi", "-i", "mandelbrot=size=640x360:rate=30",
            "-vcodec", "rawvideo", "-pix_fmt", "yuyv422",
            "-s", "640x360", "-f", "rawvideo", "-"
        ]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    elif mode == "camera":
        screenrecord_bin = None
        for candidate in ["/mnt/dm1/system/bin/screenrecord", "/system/bin/screenrecord"]:
            if os.path.exists(candidate) and os.access(candidate, os.X_OK):
                screenrecord_bin = candidate
                break

        if screenrecord_bin:
            p1 = subprocess.Popen([screenrecord_bin, "--output-format=h264", "--size", "640x360", "-"],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            p2 = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error",
                                  "-f", "h264", "-i", "-", "-vcodec", "rawvideo",
                                  "-pix_fmt", "yuyv422", "-s", "640x360", "-f", "rawvideo", "-"],
                                  stdin=p1.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            p1.stdout.close()
            proc = p2
        else:
            cmd = [
                "ffmpeg", "-hide_banner", "-loglevel", "error",
                "-re", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30",
                "-vcodec", "rawvideo", "-pix_fmt", "yuyv422",
                "-s", "640x360", "-f", "rawvideo", "-"
            ]
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    else:
        if not os.path.exists(mode):
            print(f"Error: Video file '{mode}' not found.")
            sys.exit(1)
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-re", "-stream_loop", "-1", "-i", mode,
            "-vcodec", "rawvideo", "-pix_fmt", "yuyv422",
            "-s", "640x360", "-f", "rawvideo", "-"
        ]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    try:
        while proc.poll() is None:
            frame_data = bytearray()
            while len(frame_data) < FRAME_SIZE:
                chunk = proc.stdout.read(FRAME_SIZE - len(frame_data))
                if not chunk:
                    break
                frame_data.extend(chunk)

            if len(frame_data) == FRAME_SIZE:
                with open(TMP_PATH, "wb") as f:
                    f.write(frame_data)
                os.replace(TMP_PATH, TARGET_PATH)
            else:
                break
    except KeyboardInterrupt:
        pass
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait()

if __name__ == "__main__":
    main()
