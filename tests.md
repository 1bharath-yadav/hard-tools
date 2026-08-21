# tests.md – Interactive Hardware & Feature Verification Matrix

This document tracks real-world interactive testing and verification of every hardware tool, USB Gadget, payload, and network interceptor in `hard-tools` on **DroidSpaces Arch Linux** connected to target hosts.

---

## 1. Master Testing Progress Matrix

| ID | Feature / Module | Target Script | Hardware / Interface | Status | Last Tested | Notes / Host Reaction |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **T01** | USB HID Keyboard & Typing | `usb_gadget/hid.sh` | `/dev/hidg*` (`hid.keyboard`) | ✅ **Passed** | 2026-08-20 | Keystrokes typed accurately into focused editor, virtual KB detected |
| **T02** | USB HID Precision Touchpad | `usb_gadget/hid.sh` | `hid.touchpad` / Report ID 04 | ✅ **Passed** | 2026-08-21 | Cursor moved in 200px square pattern & left-clicked on host |
| **T03** | Anti-Sleep Mouse Jiggler | `usb_gadget/hid.sh` | `hid.touchpad` / `hid.mouse` | ✅ **Passed** | 2026-08-21 | Background delta oscillation verified on host screen |
| **T04** | USB Chameleon (VID/PID Spoof) | `usb_gadget/chameleon.sh` | ConfigFS Strings & Hex IDs | ✅ **Passed** | 2026-08-21 | Spoofed Apple Magic Keyboard (05ac:024f), recognized by host OS |
| **T05** | DuckyScript 3.0 Keystroke Injection | `operator/ducky.sh` | `lib/hid_engine.py` + KB | ✅ **Passed** | 2026-08-21 | Injected Notepad trigger & multi-line text with anti-EDR typing jitter |
| **T06** | RNDIS USB Ethernet Tethering | `usb_gadget/rndis.sh` | `rndis.rndis` + `dnsmasq` | ✅ **Passed** | 2026-08-21 | Host leased 192.168.42.176 & bidirectional connectivity verified |
| **T07** | BadUSB Rogue Gateway & Captive Portal | `usb_gadget/badusb.sh` | `rndis.rndis` + `rogue_portal.py` | ✅ **Passed** | 2026-08-21 | Wildcard DNS, captive portal rendered, & credentials intercepted in real time |
| **T08** | Live PCAP Remote Streamer | `network/netfilter.sh` | `usb0` -> TCP 9999 (Wireshark) | ✅ **Passed** | 2026-08-21 | Real-time packet capture streamed over TCP 9999 socket |
| **T09** | Netfilter Port Redirection / MITM | `network/netfilter.sh` | `iptables` NAT PREROUTING | ✅ **Passed** | 2026-08-21 | Transparent NAT PREROUTING port redirection & table flushing verified |
| **T10** | Composite Multi-Gadget Stacking | `usb_gadget/composite.sh` | Ghost Drive, Stealth Jiggler | ✅ **Passed** | 2026-08-21 | Simultaneous Mouse Jiggler + RNDIS Network Gateway verified on host |
| **T11** | Mass Storage (Flash & CD-ROM ISO) | `usb_gadget/mass_storage_manager.sh` | `mass_storage.0` (LUN0) | 🟡 *Pending* | - | Disk image creation, mounting, CD-ROM flag |
| **T12** | UVC USB Webcam Gadget | `usb_gadget/uvc.sh` | `uvc.0` + `ffmpeg` v4l2 | ⚠️ *Kernel Limitation* | 2026-08-21 | UVC kernel function links, but Qualcomm f_uvc requires userspace UVCIOC event daemon |
| **T13** | ADB Gadget Switch | `usb_gadget/adb.sh` | `ffs.adb` (`function0`) | ✅ **Passed** | 2026-08-21 | Switched to native ADB function; verified working effectively |
| **T14** | MTP / PTP Media Mode | `usb_gadget/mtp_ptp.sh` | `ffs.mtp` / `ffs.ptp` | ✅ **Passed** | 2026-08-21 | Device recognized by host file manager as MTP media storage |
| **T15** | System Recon & Session Logger | `operator/recon.sh` / `session.sh` | Terminal Native | ✅ **Passed** | 2026-08-21 | SoC, UDC, interfaces, routing, sockets, and session manager verified |
| **T16** | Master Launcher TUI Dashboard | `launcher.sh` | Bash ANSI Terminal UI | ✅ **Passed** | 2026-08-21 | Unified interactive menu, category routing & live status badges verified |

---

## 2. Interactive Testing Checklist & Step-by-Step Log

### Test Group A: USB HID Subsystem & Keystroke Injection

#### Test Case T01: USB HID Keyboard Keystroke Typing
* **Objective**: Ensure host computer recognizes virtual USB keyboard and receives keystrokes accurately.
* **Commands**:
  ```bash
  # 1. Start HID Gadget
  sudo ./usb_gadget/hid.sh start
  
  # 2. Test typing a string into host (focus a Notepad or text editor on host)
  sudo ./usb_gadget/hid.sh type "Hello from Hard-Tools on DroidSpaces Arch Linux!"
  
  # 3. Test hotkey (e.g. Windows+R or Ctrl+Alt+T)
  sudo ./usb_gadget/hid.sh preset windows-run
  ```
* **Host Reaction**: Virtual keyboard recognized by host OS, exact text string typed without missing characters.
* **Verdict**: ✅ **Passed** (2026-08-20)

---

#### Test Case T02: USB HID Pointer & Touchpad
* **Objective**: Verify mouse movement and click events on the host.
* **Commands**:
  ```bash
  # Move cursor right 100px and down 100px
  sudo ./usb_gadget/hid.sh move 100 100
  
  # Left click
  sudo ./usb_gadget/hid.sh click left
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

#### Test Case T03: Anti-Sleep Mouse Jiggler
* **Objective**: Verify mouse oscillates subtly every N seconds without interfering with user.
* **Commands**:
  ```bash
  sudo ./usb_gadget/hid.sh jiggle 5 4
  # Check PID / status
  # Stop when verified:
  sudo ./usb_gadget/hid.sh jiggle-stop
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

### Test Group B: Hardware Descriptor Spoofing (USB Chameleon)

#### Test Case T04: USB Chameleon Identity Spoofing
* **Objective**: Verify host OS detects modified vendor/product names and IDs.
* **Commands**:
  ```bash
  # Apply Apple Magic Keyboard profile
  ./usb_gadget/chameleon.sh apply apple_magic_kb
  ./usb_gadget/chameleon.sh status
  
  # Check host Device Manager / lsusb / system profiler
  # Restore stock when done:
  ./usb_gadget/chameleon.sh restore
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

### Test Group C: Offensive Payloads & Keystroke Execution

#### Test Case T05: DuckyScript 3.0 Multi-OS Payloads & Typing Jitter
* **Objective**: Execute a harmless test payload with and without human typing jitter.
* **Commands**:
  ```bash
  # Run Hello World payload with jitter
  ./operator/ducky.sh run hello_world.duck jitter 3
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

### Test Group D: Network Gadgets & Rogue Interception

#### Test Case T06: RNDIS USB Ethernet Router
* **Objective**: Verify host receives IP address via DHCP and gets default route.
* **Commands**:
  ```bash
  sudo ./usb_gadget/rndis.sh start
  sudo ./usb_gadget/rndis.sh status
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

#### Test Case T07: BadUSB Rogue Gateway & Captive Portal
* **Objective**: Test rogue DHCP route override, wildcard DNS, and captive portal login capture.
* **Commands**:
  ```bash
  sudo ./usb_gadget/badusb.sh start corporate_wifi
  # On host: browse to http://anything.com or wait for captive portal prompt
  # Enter test credentials in browser
  # Check captured logs on phone:
  ./usb_gadget/badusb.sh creds
  sudo ./usb_gadget/badusb.sh stop
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

#### Test Case T08: Live PCAP Remote Streamer (Wireshark Bridge)
* **Objective**: Stream live USB network traffic over TCP socket to Wireshark on workstation.
* **Commands**:
  ```bash
  sudo ./network/netfilter.sh stream 9999
  # On workstation: ncat <phone_wlan_ip> 9999 | wireshark -k -i -
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

### Test Group E: Composite Multi-Gadget Attack Stacking

#### Test Case T10: Composite Profile Stacking
* **Objective**: Verify simultaneous binding of Mass Storage + BadUSB RNDIS + Virtual Keyboard without UDC conflicts.
* **Commands**:
  ```bash
  sudo ./usb_gadget/composite.sh ghost
  sudo ./usb_gadget/composite.sh status
  sudo ./usb_gadget/composite.sh stop
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

### Test Group F: Media, Video & Camera

#### Test Case T11: USB Mass Storage Manager
* **Objective**: Create and mount virtual disk / CD-ROM image.
* **Commands**:
  ```bash
  ./usb_gadget/mass_storage_manager.sh
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*

---

#### Test Case T12: UVC USB Webcam
* **Objective**: Mount UVC camera and stream color bars test pattern.
* **Commands**:
  ```bash
  sudo ./usb_gadget/uvc.sh start
  sudo ./usb_gadget/uvc.sh stream
  # Check camera app on host (e.g. Windows Camera, OBS, Photo Booth)
  sudo ./usb_gadget/uvc.sh stop
  ```
* **Host Reaction**:
* **Verdict**: ⚪ *Untested*
