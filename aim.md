## 🎯 Implementation Plan: USB Arsenal & More (All Features Except CD-ROM)

This plan outlines the step‑by‑step implementation of **11 features** for your `hard-tools` suite, using the DroidSpaces Arch container with passwordless `sudo`, full ConfigFS access, and existing tools (BlueZ, iptables, aircrack‑ng, etc.).  

We’ll test each feature **interactively first** (via terminal commands), then wrap it into a dedicated script, and finally integrate all scripts into a single `launcher.sh` menu.

---

### 1. Environment Recap

- **User**: `archer` (UID 1000), in Arch container(full hardware and /config binde mounted(DroidSpaces(https://www.droidspaces.org/docs/features.html), passwordless `sudo`. and rooted termux for any testing with direct root.
- **Gadget root**: `/config/usb_gadget/g1/`
- **Configs**: `configs/b.1/` (Android default)
- **Functions dir**: `functions/`
- **UDC**: `a600000.dwc3` (detected automatically)
- **Storage for images/scripts**: `/storage/emulated/0/hard-tools/`
- **Tools available**: `mkfs.*`, `losetup`, `parted`, `bluez`, `iptables`, `tcpdump`, `aircrack‑ng` (if Wi‑Fi adapter present), `ffmpeg` (for UVC), etc.

---

### 2. Feature Overview & Dependencies

| Feature | Kernel/ConfigFS Function | Additional Dependencies | Script Name |
|---------|--------------------------|-------------------------|-------------|
| **HID Keyboard** | `hid.keyboard` | None | `hid_keyboard.sh` |
| **HID Mouse** | `hid.mouse` | None | `hid_mouse.sh` |
| **Rubber Ducky Payloads** | Uses HID Keyboard + ducky‑script parser | `ducky` (custom or `duckencoder`) | `ducky.sh` |
| **BadUSB (MITM)** | `ecm` or `rndis` + `iptables` | `dnsmasq`, `mitmproxy` or custom | `badusb.sh` |
| **RNDIS Ethernet** | `rndis` | `dhcpd` / `dnsmasq` | `rndis.sh` |
| **Mass Storage** | `mass_storage.0` | `mkfs.*`, `parted` | **already done** |
| **USB Webcam (UVC)** | `uvc` | `ffmpeg`, `v4l2loopback` (or fake video source) | `uvc_webcam.sh` |
| **Bluetooth Attacks** | (Not ConfigFS – uses BlueZ) | `bluez`, `hcitool`, `l2ping`, `spooftooph` | `bt_arsenal.sh` |
| **Netfilter / MITM** | (Not ConfigFS – uses iptables) | `iptables`, `tcpdump`, `nmap` | `netfilter.sh` |
| **ADB Gadget** | `ffs.adb` | `adbd` (Android) | `adb_gadget.sh` |
| **MTP / PTP** | `mtp` / `ptp` | `mtp‑server` (user‑space) | `mtp_ptp.sh` |

> **Note**: Some features (Bluetooth, Netfilter) do **not** use ConfigFS; they run purely in userspace.  
> Monitor Mode, Packet Injection, Aircrack‑ng require a compatible Wi‑Fi adapter – those are **out of scope** for now (marked ❌).

---

### 3. General Script Template

Each feature script will follow this structure:

```bash
#!/usr/bin/env bash
# feature_name.sh – start/stop/status for a USB gadget function

start() { 
    # 1. Unbind UDC to avoid conflicts (if needed)
    # 2. Create symlink in configs/b.1/
    # 3. Configure function (write attributes)
    # 4. Bind UDC
}

stop() {
    # Unbind UDC, remove symlink, clean up
}

status() {
    # Show current state (UDC, symlink, function-specific info)
}

# Menu integration: call start/stop/status based on arguments
case "$1" in
    start) start ;;
    stop)  stop ;;
    status) status ;;
    *) echo "Usage: $0 {start|stop|status}" ;;
esac
```

We will test each feature manually first, then encode the exact steps into these functions.

---

### 4. Interactive Testing & Script Design – Per Feature

#### **4.1 HID Keyboard**  
- **Test**:  
  ```bash
  sudo sh -c 'echo 0 > /config/usb_gadget/g1/functions/hid.keyboard/protocol'
  sudo sh -c 'echo 0 > /config/usb_gadget/g1/functions/hid.keyboard/subclass'
  sudo sh -c 'echo 8 > /config/usb_gadget/g1/functions/hid.keyboard/report_length'
  # Write a simple report descriptor (e.g., 8-byte keyboard)
  sudo sh -c 'echo -n ... > /config/usb_gadget/g1/functions/hid.keyboard/report_desc'
  ln -s .../configs/b.1/
  echo a600000.dwc3 > UDC
  # Then send keystrokes via /dev/hidg0
  ```
- **Script**: `hid_keyboard.sh` with functions to send text or raw keycodes via `hidg0`.

#### **4.2 HID Mouse**  
- Similar to keyboard, but with mouse report descriptor and /dev/hidg1.  
- Test movement and clicks via `echo -ne ... > /dev/hidg1`.

#### **4.3 Rubber Ducky Payloads**  
- Build a parser that reads `.duck` scripts (e.g., from `/storage/emulated/0/hard-tools/payloads/`) and translates each line to HID keycodes.  
- Reuse the HID Keyboard script to send the sequence at high speed.

#### **4.4 BadUSB (MITM)**  
- Use `rndis` or `ecm` to present a network interface to the host.  
- Configure `iptables` to forward traffic and `dnsmasq` to serve DHCP/ DNS.  
- Optionally run `mitmproxy` to intercept HTTP(S).

#### **4.5 RNDIS Ethernet**  
- Enable `rndis` function in ConfigFS.  
- On the Android side, bring up `usb0` interface and start `dnsmasq` to assign an IP to the host.  
- Allows the host to use the phone’s internet or access a local network.

#### **4.6 Mass Storage** – already done (script integrated).

#### **4.7 UVC Webcam**  
- Enable `uvc` function; set streaming parameters (width, height, format).  
- Use `ffmpeg` to read from `/dev/video0` (or generate a test pattern) and pipe to the UVC gadget’s output.  
- Test with a host’s webcam viewer (e.g., `guvcview`).

#### **4.8 Bluetooth Attacks**  
- Not ConfigFS; use `hciconfig`, `hcitool`, `l2ping`, `spooftooph`.  
- Script will:  
  - Scan for devices (`hcitool scan`).  
  - Perform attacks (l2ping flood, BlueBorne, etc.) – depending on installed tools.  
- Also include a `bt_arsenal` menu to select attack type.

#### **4.9 Netfilter / MITM**  
- Use `iptables` to redirect traffic (e.g., port 80 to a local proxy).  
- Include `tcpdump` to capture packets.  
- Provide options for ARP spoofing (with `arpspoof`) and SSL stripping (with `sslstrip`).

#### **4.10 ADB Gadget**  
- Already present as `ffs.adb` in the gadget.  
- Ensure `adbd` is running and symlink is in the config.  
- Test by connecting to a host and running `adb devices`.

#### **4.11 MTP / PTP**  
- Enable `mtp` or `ptp` function in ConfigFS.  
- Need a user‑space `mtp‑server` to handle file transfers.  
- Test by connecting to a host and seeing the device appear as a media player.

---

### 5. Integration into `launcher.sh`

The `launcher.sh` will:

- Present a menu listing all features (with current status: started/stopped).
- For each feature, call its script with `start`, `stop`, or `status`.
- Use a shared configuration file (e.g., `/data/local/tmp/hard-tools.conf`) to persist state across reboots (optional).

**Menu snippet**:

```
========================================
   hard-tools USB Arsenal
========================================
 1) HID Keyboard       [status]
 2) HID Mouse          [status]
 3) Rubber Ducky       [status]
 ...
 0) Exit
```

When a user selects a feature, ask: `(S)tart, (T)op, (V)iew status, (B)ack`.

---

### 6. Step-by-Step Testing Order

We will implement and test in this sequence (most stable first):

1. **ADB Gadget** (already exists, just symlink).  
2. **Mass Storage** (already done).  
3. **RNDIS Ethernet** – easy to test with `dnsmasq`.  
4. **HID Keyboard** – straightforward.  
5. **HID Mouse** – similar.  
6. **Rubber Ducky** – builds on Keyboard.  
7. **BadUSB (MITM)** – uses RNDIS + iptables.  
8. **UVC Webcam** – may require extra video source.  
9. **MTP/PTP** – requires user‑space server (may need compilation).  
10. **Bluetooth Attacks** – separate from USB, but easy to test with `hciconfig`.  
11. **Netfilter / MITM** – can be combined with BadUSB.

After each feature is confirmed working interactively, we write its script and add it to `launcher.sh`.

---

### 7. Scripts Directory Structure

```
~/hard-tools/
├── launcher.sh                # Main menu
├── lib/                       # Shared functions (UDC control, logging)
│   └── utils.sh
├── scripts/                   # Feature scripts
│   ├── adb_gadget.sh
│   ├── hid_keyboard.sh
│   ├── hid_mouse.sh
│   ├── ducky.sh
│   ├── badusb.sh
│   ├── rndis.sh
│   ├── uvc_webcam.sh
│   ├── bt_arsenal.sh
│   ├── netfilter.sh
│   └── mtp_ptp.sh
├── payloads/                  # Duckyscript files
├── images/                    # Mass storage images
└── config/                    # Configuration files (dnsmasq.conf, etc.)
```

---

### 8. Next Actions

- **Immediate**: Write and test `adb_gadget.sh` (simplest).  
- Then proceed with `rndis.sh` and `hid_keyboard.sh`.  
- After each, we’ll run through a test checklist (host detection, functionality, clean stop).  
- Once all scripts are stable, finalise `launcher.sh` with a polished UI.

---

### 9. Success Criteria

- Each feature can be started and stopped without leaving dangling processes.  
- The host computer correctly recognises the gadget function (drive, keyboard, network, etc.).  
- All scripts are self‑contained and do not require internet (except optional tool installations).  
- `launcher.sh` provides a clear, user‑friendly interface.

---

-we have our kernel.config in current dir, we can check and if not support we just avoid them.

---

### 11. Final Word

We have a clear roadmap. We’ll implement each feature in a test‑driven manner: **first manually, then scripted, then integrated**. At any point, you can ask for help with a specific feature, and I’ll provide the detailed interactive commands and the corresponding script code. Let’s begin with ADB and RNDIS – the easiest wins!
