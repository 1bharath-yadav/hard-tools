# hard-tools 🛠️
> Advanced USB Gadget Arsenal, HID Controller, RNDIS Ethernet, and Hardware Operator Toolkit running inside Arch Linux container on Android (via **DroidSpaces**).

---

## 🎯 Overview

`hard-tools` transforms a rooted Android phone into a multi-function USB hardware tool leveraging the Linux Kernel **USB Gadget ConfigFS** subsystem (`/config/usb_gadget/g1`) and Qualcomm hardware UDC controllers (`a600000.dwc3`).

---

## ✨ Features

- **USB HID Controller (`scripts/usb-gadget.sh`)**:
  - Full 104-key USB Keyboard injection with configurable typing speed.
  - 12-byte Precision Touchpad (Report `0x01` relative pointer + Report `0x04` digitizer).
  - Mouse clicks, double clicks, dragging, and anti-sleep background jiggler.
  - Integrated DuckyScript subset parser.
- **USB Mass Storage (`scripts/mass_storage_manager.sh`)**:
  - FAT32/exFAT disk image emulation.
- **RNDIS USB Ethernet (`scripts/rndis.sh`)**:
  - High-speed USB network adapter + `dnsmasq` DHCP server (`192.168.42.x`).
- **USB Composite Arsenal (`scripts/composite_gadget.sh`)**:
  - Multi-function simultaneous modes (HID + Mass Storage + RNDIS + UVC Camera).
- **BadUSB & Rogue Gateway (`scripts/badusb.sh`)**:
  - Captive portal & network redirection engine.
- **UVC USB Webcam (`scripts/uvc_webcam.sh`)**:
  - Emulates UVC camera stream to host PC.
- **System Recon & Session Logger (`scripts/recon.sh`, `scripts/session.sh`)**:
  - Terminal-native system discovery and timestamped session recording.
- **Master TUI Dashboard (`launcher.sh`)**:
  - Unified interactive menu with live module status indicators.

---

## 🚀 Quick Start

Launch the master dashboard:

```bash
sudo ./launcher.sh
```

Or execute feature scripts directly:

```bash
# Start HID Gadget
sudo ./scripts/usb-gadget.sh start

# Start USB Ethernet Router
sudo ./scripts/rndis.sh start

# Start Composite Mode (HID + Storage + RNDIS)
sudo ./scripts/composite_gadget.sh hid-storage-rndis
```

---

## 📐 Architecture & Protocols

See [`.agents/`](.agents/) and [`AGENTS.md`](AGENTS.md) for architectural blueprints, capability matrices, and agent workflows.
