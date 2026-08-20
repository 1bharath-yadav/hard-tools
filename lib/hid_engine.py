#!/usr/bin/env python3
"""
hard-tools: lib/hid_engine.py
High-performance HID Keyboard, Mouse, and DuckyScript injector for Linux USB Gadget (/dev/hidg*).
"""

import sys
import os
import time
import struct
import argparse

# USB HID Keycodes (Usage Page 0x07)
MOD_NONE = 0x00
MOD_LCTRL = 0x01
MOD_LSHIFT = 0x02
MOD_LALT = 0x04
MOD_LGUI = 0x08
MOD_RCTRL = 0x10
MOD_RSHIFT = 0x20
MOD_RALT = 0x40
MOD_RGUI = 0x80

# Keycode map: char -> (modifier, keycode)
ASCII_TO_HID = {
    'a': (0, 0x04), 'b': (0, 0x05), 'c': (0, 0x06), 'd': (0, 0x07),
    'e': (0, 0x08), 'f': (0, 0x09), 'g': (0, 0x0A), 'h': (0, 0x0B),
    'i': (0, 0x0C), 'j': (0, 0x0D), 'k': (0, 0x0E), 'l': (0, 0x0F),
    'm': (0, 0x10), 'n': (0, 0x11), 'o': (0, 0x12), 'p': (0, 0x13),
    'q': (0, 0x14), 'r': (0, 0x15), 's': (0, 0x16), 't': (0, 0x17),
    'u': (0, 0x18), 'v': (0, 0x19), 'w': (0, 0x1A), 'x': (0, 0x1B),
    'y': (0, 0x1C), 'z': (0, 0x1D),
    'A': (MOD_LSHIFT, 0x04), 'B': (MOD_LSHIFT, 0x05), 'C': (MOD_LSHIFT, 0x06),
    'D': (MOD_LSHIFT, 0x07), 'E': (MOD_LSHIFT, 0x08), 'F': (MOD_LSHIFT, 0x09),
    'G': (MOD_LSHIFT, 0x0A), 'H': (MOD_LSHIFT, 0x0B), 'I': (MOD_LSHIFT, 0x0C),
    'J': (MOD_LSHIFT, 0x0D), 'K': (MOD_LSHIFT, 0x0E), 'L': (MOD_LSHIFT, 0x0F),
    'M': (MOD_LSHIFT, 0x10), 'N': (MOD_LSHIFT, 0x11), 'O': (MOD_LSHIFT, 0x12),
    'P': (MOD_LSHIFT, 0x13), 'Q': (MOD_LSHIFT, 0x14), 'R': (MOD_LSHIFT, 0x15),
    'S': (MOD_LSHIFT, 0x16), 'T': (MOD_LSHIFT, 0x17), 'U': (MOD_LSHIFT, 0x18),
    'V': (MOD_LSHIFT, 0x19), 'W': (MOD_LSHIFT, 0x1A), 'X': (MOD_LSHIFT, 0x1B),
    'Y': (MOD_LSHIFT, 0x1C), 'Z': (MOD_LSHIFT, 0x1D),
    '1': (0, 0x1E), '2': (0, 0x1F), '3': (0, 0x20), '4': (0, 0x21),
    '5': (0, 0x22), '6': (0, 0x23), '7': (0, 0x24), '8': (0, 0x25),
    '9': (0, 0x26), '0': (0, 0x27),
    '!': (MOD_LSHIFT, 0x1E), '@': (MOD_LSHIFT, 0x1F), '#': (MOD_LSHIFT, 0x20),
    '$': (MOD_LSHIFT, 0x21), '%': (MOD_LSHIFT, 0x22), '^': (MOD_LSHIFT, 0x23),
    '&': (MOD_LSHIFT, 0x24), '*': (MOD_LSHIFT, 0x25), '(': (MOD_LSHIFT, 0x26),
    ')': (MOD_LSHIFT, 0x27),
    '\n': (0, 0x28), '\r': (0, 0x28), '\t': (0, 0x2B), ' ': (0, 0x2C),
    '-': (0, 0x2D), '_': (MOD_LSHIFT, 0x2D),
    '=': (0, 0x2E), '+': (MOD_LSHIFT, 0x2E),
    '[': (0, 0x2F), '{': (MOD_LSHIFT, 0x2F),
    ']': (0, 0x30), '}': (MOD_LSHIFT, 0x30),
    '\\': (0, 0x31), '|': (MOD_LSHIFT, 0x31),
    ';': (0, 0x33), ':': (MOD_LSHIFT, 0x33),
    '\'': (0, 0x34), '"': (MOD_LSHIFT, 0x34),
    '`': (0, 0x35), '~': (MOD_LSHIFT, 0x35),
    ',': (0, 0x36), '<': (MOD_LSHIFT, 0x36),
    '.': (0, 0x37), '>': (MOD_LSHIFT, 0x37),
    '/': (0, 0x38), '?': (MOD_LSHIFT, 0x38),
}

SPECIAL_KEYS = {
    'ENTER': (0, 0x28), 'RETURN': (0, 0x28),
    'ESCAPE': (0, 0x29), 'ESC': (0, 0x29),
    'BACKSPACE': (0, 0x2A),
    'TAB': (0, 0x2B),
    'SPACE': (0, 0x2C),
    'CAPSLOCK': (0, 0x39),
    'F1': (0, 0x3A), 'F2': (0, 0x3B), 'F3': (0, 0x3C), 'F4': (0, 0x3D),
    'F5': (0, 0x3E), 'F6': (0, 0x3F), 'F7': (0, 0x40), 'F8': (0, 0x41),
    'F9': (0, 0x42), 'F10': (0, 0x43), 'F11': (0, 0x44), 'F12': (0, 0x45),
    'PRINTSCREEN': (0, 0x46), 'SCROLLLOCK': (0, 0x47), 'PAUSE': (0, 0x48),
    'INSERT': (0, 0x49), 'HOME': (0, 0x4A), 'PAGEUP': (0, 0x4B),
    'DELETE': (0, 0x4C), 'END': (0, 0x4D), 'PAGEDOWN': (0, 0x4E),
    'RIGHT': (0, 0x4F), 'RIGHTARROW': (0, 0x4F),
    'LEFT': (0, 0x50), 'LEFTARROW': (0, 0x50),
    'DOWN': (0, 0x51), 'DOWNARROW': (0, 0x51),
    'UP': (0, 0x52), 'UPARROW': (0, 0x52),
    'MENU': (0, 0x65), 'APP': (0, 0x65),
    'GUI': (MOD_LGUI, 0), 'WINDOWS': (MOD_LGUI, 0), 'COMMAND': (MOD_LGUI, 0),
    'CTRL': (MOD_LCTRL, 0), 'CONTROL': (MOD_LCTRL, 0),
    'SHIFT': (MOD_LSHIFT, 0),
    'ALT': (MOD_LALT, 0),
}

class USBKeyboard:
    def __init__(self, dev_path=None):
        if dev_path is None:
            # Auto-detect keyboard hidg device
            dev_path = self._find_keyboard_dev()
        self.dev_path = dev_path

    def _find_keyboard_dev(self):
        for dev in ['/dev/hidg0', '/dev/hidg1', '/dev/hidg2']:
            if os.path.exists(dev):
                return dev
        return '/dev/hidg0'

    def send_report(self, mod=0, key1=0, key2=0, key3=0, key4=0, key5=0, key6=0):
        if not os.path.exists(self.dev_path):
            raise FileNotFoundError(f"HID device {self.dev_path} not found. Is HID gadget active and bound?")
        report = bytes([mod, 0x00, key1, key2, key3, key4, key5, key6])
        with open(self.dev_path, 'wb') as f:
            f.write(report)
            f.flush()

    def release_all(self):
        self.send_report(0, 0, 0, 0, 0, 0, 0)

    def tap_key(self, mod, keycode, delay=0.015):
        self.send_report(mod, keycode)
        time.sleep(delay)
        self.release_all()
        time.sleep(delay)

    def write_string(self, text, char_delay=0.01):
        for ch in text:
            if ch in ASCII_TO_HID:
                mod, code = ASCII_TO_HID[ch]
                self.tap_key(mod, code, delay=char_delay)
            else:
                # Unsupported char fallback
                pass

    def send_combo(self, combo_str, delay=0.02):
        parts = [p.strip().upper() for p in combo_str.replace('+', ' ').replace('-', ' ').split()]
        mod = 0
        keycodes = []

        for p in parts:
            if p in ['GUI', 'WINDOWS', 'WIN', 'SUPER', 'COMMAND']:
                mod |= MOD_LGUI
            elif p in ['CTRL', 'CONTROL']:
                mod |= MOD_LCTRL
            elif p in ['SHIFT']:
                mod |= MOD_LSHIFT
            elif p in ['ALT', 'OPTION']:
                mod |= MOD_LALT
            elif p in ['ALTGR', 'RALT']:
                mod |= MOD_RALT
            elif p in SPECIAL_KEYS:
                smod, scode = SPECIAL_KEYS[p]
                mod |= smod
                if scode != 0:
                    keycodes.append(scode)
            elif len(p) == 1 and p.lower() in ASCII_TO_HID:
                cmod, ccode = ASCII_TO_HID[p.lower()]
                mod |= cmod
                keycodes.append(ccode)

        k1 = keycodes[0] if len(keycodes) > 0 else 0
        k2 = keycodes[1] if len(keycodes) > 1 else 0
        k3 = keycodes[2] if len(keycodes) > 2 else 0

        self.send_report(mod, k1, k2, k3)
        time.sleep(delay)
        self.release_all()
        time.sleep(delay)


class USBMouse:
    def __init__(self, dev_path=None):
        if dev_path is None:
            dev_path = self._find_mouse_dev()
        self.dev_path = dev_path

    def _find_mouse_dev(self):
        for dev in ['/dev/hidg1', '/dev/hidg0', '/dev/hidg2']:
            if os.path.exists(dev):
                return dev
        return '/dev/hidg1'

    def send_report(self, buttons=0, x=0, y=0, wheel=0):
        if not os.path.exists(self.dev_path):
            raise FileNotFoundError(f"HID device {self.dev_path} not found. Is HID mouse active?")
        # Convert signed -128..127 to signed byte
        def to_byte(v):
            return struct.pack('b', max(-127, min(127, int(v))))[0]
        report = bytes([buttons & 0x07, to_byte(x), to_byte(y), to_byte(wheel)])
        with open(self.dev_path, 'wb') as f:
            f.write(report)
            f.flush()

    def move(self, dx, dy, wheel=0):
        self.send_report(buttons=0, x=dx, y=dy, wheel=wheel)

    def click(self, button='left', count=1, delay=0.05):
        btn_mask = 1 if button == 'left' else (2 if button == 'right' else 4)
        for _ in range(count):
            self.send_report(buttons=btn_mask)
            time.sleep(delay)
            self.send_report(buttons=0)
            time.sleep(delay)

    def jiggle(self, interval=30, distance=5, duration=None):
        print(f"[*] Mouse Jiggler started (Interval: {interval}s, Distance: {distance}px). Press Ctrl+C to stop.")
        start_time = time.time()
        try:
            while True:
                if duration and (time.time() - start_time) > duration:
                    break
                self.move(distance, 0)
                time.sleep(0.1)
                self.move(-distance, 0)
                time.sleep(0.1)
                self.move(0, distance)
                time.sleep(0.1)
                self.move(0, -distance)
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n[*] Jiggler stopped.")


class DuckyParser:
    def __init__(self, keyboard, default_delay=0.05):
        self.kb = keyboard
        self.default_delay = default_delay

    def run_file(self, filepath):
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"Payload file '{filepath}' not found.")
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        self.run_lines(lines)

    def run_lines(self, lines):
        last_line = ""
        def_delay = self.default_delay

        for raw_line in lines:
            line = raw_line.strip()
            if not line or line.startswith("REM") or line.startswith("#"):
                continue

            parts = line.split(" ", 1)
            cmd = parts[0].upper()
            args = parts[1] if len(parts) > 1 else ""

            if cmd == "DEFAULT_DELAY" or cmd == "DEFAULTDELAY":
                def_delay = float(args) / 1000.0
            elif cmd == "DELAY":
                delay_ms = float(args) if args else 100
                time.sleep(delay_ms / 1000.0)
            elif cmd == "STRING":
                self.kb.write_string(args)
            elif cmd == "REPEAT":
                count = int(args) if args.isdigit() else 1
                for _ in range(count):
                    self.run_lines([last_line])
            else:
                # Key or combo (e.g. GUI r, CTRL-ALT-DELETE, ENTER, etc.)
                self.kb.send_combo(line)

            last_line = line
            time.sleep(def_delay)


def main():
    parser = argparse.ArgumentParser(description="hard-tools HID Engine")
    subparsers = parser.add_subparsers(dest="subcommand")

    # Keyboard subcommands
    p_type = subparsers.add_parser("type", help="Type plain text")
    p_type.add_argument("text", help="String to type")
    p_type.add_argument("--delay", type=float, default=0.01, help="Delay between characters")
    p_type.add_argument("--dev", default=None, help="HID device path")

    p_key = subparsers.add_parser("key", help="Send a key combination (e.g. 'GUI r' or 'CTRL+ALT+DELETE')")
    p_key.add_argument("combo", help="Key combo")
    p_key.add_argument("--dev", default=None, help="HID device path")

    # Mouse subcommands
    p_move = subparsers.add_parser("mouse-move", help="Move mouse cursor")
    p_move.add_argument("x", type=int, help="Delta X")
    p_move.add_argument("y", type=int, help="Delta Y")
    p_move.add_argument("--dev", default=None, help="HID device path")

    p_click = subparsers.add_parser("mouse-click", help="Click mouse button")
    p_click.add_argument("button", choices=["left", "right", "middle"], default="left", nargs="?")
    p_click.add_argument("--count", type=int, default=1, help="Click count (2 for double-click)")
    p_click.add_argument("--dev", default=None, help="HID device path")

    p_jiggle = subparsers.add_parser("mouse-jiggle", help="Mouse Jiggler anti-sleep tool")
    p_jiggle.add_argument("--interval", type=int, default=15, help="Interval in seconds")
    p_jiggle.add_argument("--dist", type=int, default=5, help="Pixel distance")
    p_jiggle.add_argument("--dev", default=None, help="HID device path")

    # Ducky subcommands
    p_duck = subparsers.add_parser("ducky", help="Execute DuckyScript file")
    p_duck.add_argument("file", help="Path to .duck script")
    p_duck.add_argument("--dev", default=None, help="HID device path")

    args = parser.parse_args()

    if args.subcommand == "type":
        kb = USBKeyboard(args.dev)
        kb.write_string(args.text, char_delay=args.delay)
    elif args.subcommand == "key":
        kb = USBKeyboard(args.dev)
        kb.send_combo(args.combo)
    elif args.subcommand == "mouse-move":
        m = USBMouse(args.dev)
        m.move(args.x, args.y)
    elif args.subcommand == "mouse-click":
        m = USBMouse(args.dev)
        m.click(args.button, count=args.count)
    elif args.subcommand == "mouse-jiggle":
        m = USBMouse(args.dev)
        m.jiggle(interval=args.interval, distance=args.dist)
    elif args.subcommand == "ducky":
        kb = USBKeyboard(args.dev)
        dp = DuckyParser(kb)
        dp.run_file(args.file)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
