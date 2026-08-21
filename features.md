# features.md – Hard-Tools Feature Catalog & Offensive Roadmap

This document serves as the master feature catalog, capability matrix, and technical roadmap for the `hard-tools` hardware penetration testing and USB gadget weaponization suite.

---

## 1. Project Mission & Architectural Philosophy

`hard-tools` is built for **advanced hardware penetration testing, offensive/defensive hardware research, and USB Gadget weaponization** (BadUSB, Rubber Ducky keystroke injection, rogue network gateways, hardware descriptor spoofing, and low-level hardware reconnaissance). It is **not** a basic utility collection of administrative on/off switches.

### Dual Execution Architecture

```
+-----------------------------------------------------------------------------------+
|                                    HARD-TOOLS                                     |
+-----------------------------------------+-----------------------------------------+
|      1. DROIDSPACES ARCH CONTAINER      |       2. ROOTED TERMUX / ANDROID        |
|      (USB Gadget ConfigFS Arsenal)      |       (Android Bluetooth Arsenal)       |
+-----------------------------------------+-----------------------------------------+
| • Kernel USB ConfigFS Subsystem         | • Android BluetoothManagerService       |
| • Hardware UDC (a600000.dwc3)           | • dumpsys bluetooth_manager             |
| • Mass Storage (CD-ROM / Flash Drive)   | • cmd bluetooth_manager                 |
| • Consolidated USB HID Digitizer        | • service call bluetooth_manager        |
| • Composite Multi-Gadget Engine         | • BLE Multi-Advertising (16 sets)       |
| • RNDIS + Captive Portal (BadUSB)       | • Hardware Audio Codec Offload (31 DSP) |
| • UVC USB Webcam & MTP/PTP              | • PAN Tethering & Device Inspection     |
| • Netfilter NAT & Packet Capture        | • Sub-Millisecond Binder Fast Path      |
+-----------------------------------------+-----------------------------------------+
```

---

## 2. Master Feature Status Matrix

| Subsystem / Feature | Runtime Environment | Underlying Technology | Current Status | Description & Pentest Capability |
| :--- | :--- | :--- | :---: | :--- |
| **USB Mass Storage** | DroidSpaces Arch | Kernel ConfigFS `mass_storage.0` | ✅ **Implemented** | Working USB Mass Storage manager supporting CD-ROM ISO & Flash images (`usb_gadget/mass_storage_manager.sh`). |
| **Consolidated USB HID** | DroidSpaces Arch | Kernel ConfigFS `hid.keyboard` / `hid.touchpad` | ✅ **Implemented** | Consolidated 8-byte Keyboard, 12-byte Precision Touchpad, Mouse Jiggler, and Ducky parser (`usb_gadget/hid.sh`). |
| **USB Chameleon (VID/PID Spoof)** | DroidSpaces Arch | Dynamic ConfigFS Descriptor Rewriter | ✅ **Implemented** | Spoofs vendor/product IDs (Apple, Logitech, Dell, SanDisk, Microsoft, Corsair, Kingston) to bypass USB endpoint whitelisting / EDR (`usb_gadget/chameleon.sh`). |
| **Composite Multi-Gadget Engine** | DroidSpaces Arch | Multi-Function ConfigFS Stack | ✅ **Implemented** | One-click arming of synchronized attack profiles: Ghost Drive, Stealth Jiggler, BadUSB Auto-Pwn, Full Arsenal (`usb_gadget/composite.sh`). |
| **Weaponized Ducky 3.0 Arsenal** | DroidSpaces Arch | Multi-OS Staged Keystroke Engine | ✅ **Implemented** | Curated multi-stage automated payload suite for Windows 10/11, Linux, macOS with human typing jitter (`operator/ducky.sh` & `lib/hid_engine.py`). |
| **BadUSB Rogue Gateway Hijack** | DroidSpaces Arch | `rndis.rndis` + `dnsmasq` + `iptables` | ✅ **Implemented** | RFC Option 3/6/121/249/252 default route hijacking, wildcard DNS, and multi-template captive portal (`usb_gadget/badusb.sh` & `lib/rogue_portal.py`). |
| **RNDIS USB Ethernet** | DroidSpaces Arch | Kernel ConfigFS `rndis.rndis` | ✅ **Implemented** | Provides USB Ethernet tethering and local DHCP router gateway to host (`usb_gadget/rndis.sh`). |
| **Live PCAP Remote Streamer** | DroidSpaces Arch | `tcpdump` + Netcat / Remote Wireshark | ✅ **Implemented** | Streams real-time PCAP packet capture from `usb0` interface directly to a remote Wireshark listener (`network/netfilter.sh`). |
| **Transparent Port Redirection** | DroidSpaces Arch | `iptables` REDIRECT + Sniffer | ✅ **Implemented** | Transparent port 80/8080 interception, DNS query sniffing, and plaintext credential harvesting (`network/netfilter.sh`). |
| **UVC USB Webcam** | DroidSpaces Arch | Kernel ConfigFS `uvc.0` | ✅ **Implemented** | Emulates USB Video Class (UVC) webcam device and streaming feed (`usb_gadget/uvc.sh`). |
| **ADB Gadget Switch** | DroidSpaces Arch | Kernel ConfigFS `ffs.adb` | ✅ **Implemented** | Seamless switching between USB Gadget modes and Android Debug Bridge (`usb_gadget/adb.sh`). |
| **MTP / PTP Media Mode** | DroidSpaces Arch | Kernel ConfigFS `ffs.mtp` / `ffs.ptp` | ✅ **Implemented** | Emulates Media Transfer Protocol and Picture Transfer Protocol (`usb_gadget/mtp_ptp.sh`). |
| **Master TUI Launcher** | Dual Runtime | Interactive ANSI Bash Dashboard | ✅ **Implemented** | Central unified terminal UI with real-time gadget and Bluetooth status indicators (`launcher.sh`). |
| **Android Bluetooth Arsenal** | Rooted Termux | `android.bluetooth.IBluetoothManager` | ✅ **Implemented** | 22 dedicated tools for fast Binder querying, real-time scan telemetry, security auditing, codecs, and PAN. |
| **External OTG Wi-Fi / Dongles** | DroidSpaces Arch | USB OTG Host Kernel Modules | ❌ **Excluded** | Wi-Fi packet injection / external dongles explicitly out of scope (no external hardware reliance). |

---

## 3. Currently Available Features (Detailed Breakdown)

### 3.1 USB Gadget Arsenal (DroidSpaces Arch Linux)

* **USB Mass Storage Manager (`usb_gadget/mass_storage_manager.sh`)**:
  * Emulates USB Flash drives and CD-ROM optical drives using kernel ConfigFS (`mass_storage.0`).
  * Supports creating, formatting, and mounting raw disk images (.img / .iso).
  * Direct LUN configuration: Read-Only flag, Removable media flag, CD-ROM mode toggle.
  * *Rule*: Keep untouched as verified working.

* **Consolidated USB HID Controller (`usb_gadget/hid.sh`)**:
  * Consolidates virtual keyboard (`hid.keyboard`) and pointer (`hid.touchpad` / `hid.mouse`) into a single engine.
  * Dynamic device detection (`/dev/hidg*` mapping via `/config/usb_gadget/g1/functions/hid.*/dev`).
  * 8-byte standard keyboard descriptor with full 104-key US layout translation.
  * 12-byte Precision Touchpad digitizer with absolute coordinates, tap-to-click, and mouse buttons.
  * Built-in Anti-Sleep Hardware Mouse Jiggler with randomized intervals.
  * Hak5 DuckyScript runner for automated keystroke injection.

* **BadUSB Rogue Gateway & Captive Portal (`usb_gadget/badusb.sh`)**:
  * Activates RNDIS Ethernet gadget (`rndis.rndis`) and assigns IP subnet `192.168.42.0/24`.
  * Runs lightweight `dnsmasq` to assign host IP and hijack DNS queries.
  * Spins up a rogue HTTP captive portal (`lib/rogue_portal.py`) capturing submitted credentials.

* **UVC USB Webcam Gadget (`scripts/uvc_webcam.sh`)**:
  * Emulates USB Video Class gadget (`uvc.0`) with streaming endpoints.
  * Generates test video streams or feeds video source to the host.

* **Netfilter & Sniffer (`scripts/netfilter.sh`)**:
  * Manages `iptables` NAT forwarding between host USB interface (`usb0`) and Android uplink (`wlan0`/`rmnet0`).
  * Performs live packet captures via `tcpdump` with filtered PCAP output.

---

### 3.2 Android Native Bluetooth Arsenal (Rooted Termux)

The Bluetooth Arsenal operates natively via Android's `bluetooth_manager` system service (`android.bluetooth.IBluetoothManager`):

```
bluetooth/
├── Tier 1: Lifecycle & Inventory
│   ├── bt-status              # Live status, power, MAC, uptime & connected sinks
│   ├── bt-paired              # Fast tabular inventory (Name | MAC | Transport | CoD)
│   ├── bt-discovery           # Discovery and inquiry lifecycle status & controller
│   ├── bt-events              # Real-time event stream (SCAN, ACL, SDP, RFCOMM) from shim::btm
│   └── bt-reset               # 4-stage soft recovery cycling with Binder state convergence
├── Tier 2: Reconnaissance & Security
│   ├── bt-device-info         # Deep target recon (Class of Device, UUIDs, Policies)
│   ├── bt-services            # Advertised services and standard UUID translator
│   ├── bt-security            # Security auditor (Link key types, MITM, P-256 SC)
│   └── bt-audio               # Audio stack, active sink routing & DSP offload mask
├── Tier 3: PAN Gateway
│   ├── bt-pan                 # Personal Area Network (NAP/PANU) state & configuration
│   └── bt-pan-status          # Dedicated PAN interface and gateway status
├── Tier 4: BLE Engine
│   ├── bt-ble-info            # BLE 5.0+ multi-advertising specs (16 sets, 1650B)
│   ├── bt-ble-clients         # Active BLE scanner client applications and filters
│   └── bt-scan                # Flagship scanner telemetry & start/stop event stream
└── Tier 5: Binder Fast Path
    ├── bt-status-fast         # Sub-millisecond state querying (TXN 3/6/7)
    ├── bt-binder-map          # Automated Binder transaction code enumerator
    └── bt-watch               # Continuous ANSI live dashboard monitor
```

---

## 4. Planned Offensive Features (Active Development Roadmap)

Development is strictly focused on **Category 1 (USB Weaponization & BadUSB Arsenal)** and **Category 2 (Network MITM & Traffic Interception)** using the device's internal hardware and kernel capabilities.

### Category 1: Advanced USB Weaponization & BadUSB Arsenal

#### 1. USB Chameleon: Dynamic Descriptor & Hardware Identity Cloner
* **Objective**: Bypass enterprise USB device whitelisting, Endpoint Detection & Response (EDR) peripheral controls, and OS-level device restrictions.
* **Mechanism**: Script that dynamically unbinds UDC, rewrites ConfigFS descriptor strings and hex identifiers, and rebinds to host:
  * `idVendor` & `idProduct`: Spoofs legitimate hardware vendors (Apple, Logitech, Dell, Microsoft, SanDisk).
  * `bcdDevice` & `bcdUSB`: Sets USB specification versions (USB 2.0 / USB 3.0).
  * `iManufacturer`, `iProduct`, `iSerialNumber`: Injects legitimate manufacturer strings.
* **Pre-Baked Profiles**:
  * `apple_magic_kb`: Apple Inc. Magic Keyboard (`05ac:024f`)
  * `logitech_unifying`: Logitech USB Receiver (`046d:c52b`)
  * `dell_multimedia`: Dell Pro Business Keyboard (`413c:2113`)
  * `sandisk_cruzer`: SanDisk Cruzer Glide Flash Drive (`0781:5575`)
  * `microsoft_mouse`: Microsoft Optical Mouse (`045e:00cb`)

#### 2. Weaponized Multi-OS DuckyScript 3.0 & Staged Payload Arsenal
* **Objective**: Automated, high-speed keystroke injection tailored to target host operating systems with typing jitter to bypass heuristic behavioral detection.
* **Payload Categories**:
  * **Windows 10/11 Payloads**:
    * `win_recon_fast.duck`: In-memory system inventory (users, network adapters, running AV/EDR, firewall rules).
    * `win_wifi_extract.duck`: Extracts cleartext saved Wi-Fi profiles and passwords.
    * `win_uac_bypass_stage.duck`: Staged user-context execution.
  * **Linux Payloads**:
    * `lin_recon.duck`: Quick user, sudoers, kernel, and network interface enumeration.
    * `lin_ssh_grab.duck`: Harvests `.ssh/id_rsa`, `.ssh/authorized_keys`, and bash history.
    * `lin_sudo_prompt.duck`: Local privilege escalation simulation prompt.
  * **macOS Payloads**:
    * `mac_recon.duck`: macOS system profiler, hardware UUID, and network routing tables.
    * `mac_terminal_exec.duck`: Spotlight-based background execution staging.

#### 3. BadUSB Advanced Gateway Hijack & Route Override
* **Objective**: Force the target host to route all outbound TCP/UDP network traffic through the phone over the USB cable without requiring physical Ethernet.
* **Mechanism**: Enhanced DHCP server configuration pushing aggressive RFC options:
  * `Option 3 (routers)`: `0.0.0.0/0` (Overrides the host default gateway).
  * `Option 6 (DNS servers)`: Points DNS directly to the phone's local DNS responder.
  * `Option 121 (Classless Static Routes)`: Injects static routes for internal subnets.
  * Dynamic captive portal redirecting HTTP traffic to local phishing/credential harvesting templates.

#### 4. Composite Attack Profiles (One-Click Multi-Function Stacking)
* **Objective**: Launch synchronized multi-stage attacks upon USB insertion.
* **Profiles**:
  * **Ghost Drive**: Mounts read-only CD-ROM ISO + BadUSB RNDIS Network + Virtual Keyboard simultaneously.
  * **Stealth Jiggler**: Runs subtle mouse movement in background while maintaining an active RNDIS network tap.

---

### Category 2: Network MITM & Traffic Interception (Netfilter Engine)

#### 5. Transparent Port Redirection & Credential Logger
* **Objective**: Intercept unencrypted HTTP/DNS network traffic passing through the `usb0` interface.
* **Mechanism**:
  * Automated `iptables` PREROUTING rules redirecting port 80/8080 to a local logging proxy.
  * Captures plaintext HTTP POST requests, authentication tokens, and headers into structured logs.
  * DNS Spoofer responding with spoofed IPs for targeted domains.

#### 6. Live PCAP Remote Streamer & Wireshark Bridge
* **Objective**: Real-time traffic analysis of host USB network traffic from an external monitoring machine.
* **Mechanism**:
  * Streamlined piping of `tcpdump` output on interface `usb0` over SSH or Netcat socket directly to Wireshark:
    ```bash
    tcpdump -i usb0 -U -s 0 -w - not port 22 | nc -l -p 9999
    ```

---

## 5. Explicit Scope Boundaries

> [!NOTE]
> The following subsystems are **explicitly excluded** from `hard-tools`:
> * **External OTG Dongles**: No reliance on external USB Wi-Fi dongles (Atheros/Realtek), external USB Bluetooth dongles, or RTL-SDR hardware.
> * **Internal Wi-Fi Packet Injection**: Internal mobile Wi-Fi chipsets do not support monitor mode/packet injection on native Android kernel drivers.
> 
> All offensive capabilities are designed to execute **100% self-contained** using the device's internal USB Gadget controller (Qualcomm DWC3 UDC) and native Android framework services.
