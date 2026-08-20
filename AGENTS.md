# AGENTS.md – Hard-Tools USB Arsenal & Gadget Suite

This file serves as the definitive reference guide and operating manual for AI agents and developers working on the `hard-tools` codebase.

---

## 1. Project Mission & System Architecture

`hard-tools` is an advanced USB Gadget Arsenal and offensive/defensive hardware tooling suite running inside an Arch Linux container on Android (via **DroidSpaces**).

It leverages the Linux Kernel **USB Gadget ConfigFS** subsystem (`/config/usb_gadget/g1`), the Android hardware UDC controller, and userspace network/wireless utilities to turn the mobile device into a versatile multi-function hardware tool.

---

## 2. Environment & Permissions

- **User**: `archer` (UID 1000)
- **Privileges**: Passwordless `sudo` configured in `/etc/sudoers.d/archer`.
- **Gadget Root**: `/config/usb_gadget/g1/`
- **Active Config**: `/config/usb_gadget/g1/configs/b.1/`
- **Functions Dir**: `/config/usb_gadget/g1/functions/`
- **Hardware UDC**: `a600000.dwc3` (auto-detected via `/sys/class/udc/`)
- **Shared Storage**: `/storage/emulated/0/hard-tools/`
  - Disk Images: `/storage/emulated/0/hard-tools/drive/` (fallback: `./images/`)
  - Payloads: `/storage/emulated/0/hard-tools/payloads/` (fallback: `./payloads/`)

---

## 3. Critical Rules for Agents

> [!IMPORTANT]
> 1. **DO NOT MODIFY `scripts/mass_storage_manager.sh`**: The existing `scripts/mass_storage_manager.sh` script is fully working and verified. Keep it untouched. `launcher.sh` calls `scripts/mass_storage_manager.sh` directly for Mass Storage management.
> 2. **ConfigFS UDC Handling**: You **MUST unbind UDC** with `echo none > /config/usb_gadget/g1/UDC` before adding or removing symlinks in `configs/b.1/`. After changing links, rebind to `a600000.dwc3`.
> 3. **Consolidated HID Controller (`scripts/usb-gadget.sh`)**: Keyboard and Pointer (touchpad/mouse) are consolidated into `scripts/usb-gadget.sh` using dynamic device discovery (`cat $G/functions/hid.*/dev` -> `/dev/hidg*`).
> 4. **Self-Contained & Clean Exit**: Every script must support both non-interactive execution (`start`, `stop`, `status`) and interactive UI. No background processes or dangling symlinks should remain after stopping a module.

---

## 4. Directory Structure

```
hard-tools/
├── AGENTS.md                  # This developer & agent guide
├── aim.md                     # Initial roadmap and feature specification
├── kernel.config              # Active kernel build configuration
├── launcher.sh                # Interactive master TUI menu (only script in root)
├── lib/
│   ├── utils.sh               # Central helper library (UDC, ConfigFS, colors, logging)
│   ├── hid_keymap.sh          # 104-key USB keycode & modifier mapping
│   ├── hid_touch.sh           # Precision Touchpad digitizer engine
│   ├── hid_engine.py          # Python HID engine & Ducky parser
│   └── rogue_portal.py        # Captive portal & credential logger
├── scripts/                   # Feature-specific gadget and tool scripts
│   ├── mass_storage_manager.sh# [DO NOT MODIFY] Working USB Mass Storage manager
│   ├── usb-gadget.sh          # Consolidated USB HID Controller (Keyboard & Pointer)
│   ├── composite_gadget.sh    # Multi-function Composite Controller
│   ├── adb_gadget.sh          # ADB gadget mode switch
│   ├── rndis.sh               # RNDIS Ethernet + DHCP/DNS router
│   ├── ducky.sh               # Hak5 DuckyScript runner
│   ├── badusb.sh              # Rogue gateway, captive portal & DNS spoofer
│   ├── uvc_webcam.sh          # UVC USB Webcam gadget
│   ├── bt_arsenal.sh          # BlueZ Bluetooth recon & L2ping tools
│   ├── netfilter.sh           # Iptables NAT/redirection & packet capture
│   └── mtp_ptp.sh             # MTP/PTP media transfer gadget
├── payloads/                  # DuckyScript payloads (.duck / .txt)
├── config/                    # Configuration templates (dnsmasq.conf, etc.)
└── images/                    # Local mass storage disk images
```

---

## 5. Status of Features

| Feature | Script | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Mass Storage** | `mass_storage_manager.sh` | ✅ Done | Working great. DO NOT MODIFY. |
| **USB HID Controller** | `scripts/usb-gadget.sh` | ✅ Done | Dynamic mapping, 8-byte KB, 12-byte pointer, Jiggler, Ducky. |
| **ADB Gadget** | `scripts/adb_gadget.sh` | ✅ Done | Controls `ffs.adb`. |
| **RNDIS Ethernet** | `scripts/rndis.sh` | ✅ Done | Uses `rndis.rndis` + `dnsmasq`. |
| **BadUSB (MITM)** | `scripts/badusb.sh` | ✅ Done | RNDIS + DNS spoofing / captive portal. |
| **UVC Webcam** | `scripts/uvc_webcam.sh` | ✅ Done | `uvc.0` descriptor & test feed. |
| **Bluetooth Suite** | `scripts/bt_arsenal.sh` | ✅ Done | BlueZ `l2ping`, `bluetoothctl`, recon. |
| **Netfilter / Sniff** | `scripts/netfilter.sh` | ✅ Done | `iptables` port redirect + `tcpdump`. |
| **MTP / PTP** | `scripts/mtp_ptp.sh` | ✅ Done | `ffs.mtp` & `ffs.ptp` mode. |
| **Master Launcher** | `launcher.sh` | ✅ Done | Unified menu dashboard. |
