# AGENTS.md – Hard-Tools USB Arsenal & Gadget Suite

This file serves as the definitive reference guide and operating manual for AI agents and developers working on the `hard-tools` codebase.

---

## 1. Project Mission & Core Philosophy

> [!IMPORTANT]
> **Core Purpose**: `hard-tools` is built for **advanced hardware penetration testing, offensive/defensive hardware research, and USB Gadget weaponization** (BadUSB, Rubber Ducky keystroke injection, rogue network gateways, hardware descriptor spoofing, and low-level hardware reconnaissance). It is **not** a basic utility collection of administrative on/off switches.

`hard-tools` operates across a **Dual Execution Architecture**:

```
+-------------------------------------------------------------------------+
|                              HARD-TOOLS                                 |
+------------------------------------+------------------------------------+
|   1. DROIDSPACES ARCH CONTAINER    |     2. ROOTED TERMUX / ANDROID     |
|   (USB Gadget ConfigFS Arsenal)    |    (Android Bluetooth Arsenal)     |
+------------------------------------+------------------------------------+
| • Kernel USB ConfigFS Subsystem    | • Android BluetoothManagerService  |
| • Hardware UDC (a600000.dwc3)      | • dumpsys bluetooth_manager        |
| • Mass Storage (CD-ROM/Flash)      | • cmd bluetooth_manager            |
| • Consolidated USB HID Digitizer   | • service call bluetooth_manager   |
| • Composite Multi-Gadget Engine    | • BLE Multi-Advertising (16 sets)  |
| • RNDIS + Captive Portal (BadUSB)  | • Hardware Audio Codec Offload     |
| • UVC USB Webcam & MTP/PTP         | • PAN Tethering & Device Inspection|
+------------------------------------+------------------------------------+
```

### Environment 1: DroidSpaces Arch Linux Container
- **Target Role**: USB Gadget Subsystem, ConfigFS management, kernel UDC routing, mass storage disk mounting, virtual keyboard/touchpad HID injections, captive network routing.
- **User**: `archer` (UID 1000) with passwordless `sudo` in `/etc/sudoers.d/archer`.
- **Gadget Root**: `/config/usb_gadget/g1/`
- **Active Config**: `/config/usb_gadget/g1/configs/b.1/`
- **Functions Dir**: `/config/usb_gadget/g1/functions/`
- **Hardware UDC**: `a600000.dwc3` (auto-detected via `/sys/class/udc/`)
- **Shared Storage**: `/storage/emulated/0/hard-tools/`
  - Disk Images: `/storage/emulated/0/hard-tools/drive/` (fallback: `./images/`)
  - Payloads: `/storage/emulated/0/hard-tools/payloads/` (fallback: `./payloads/`)

### Environment 2: Rooted Termux (Native Android Framework)
- **Target Role**: Android Bluetooth Arsenal and native framework inspection.
- **Access**: Elevated Android root shell (`su -c`).
- **Mechanism**: Communicates directly with Android's `bluetooth_manager` system service (`android.bluetooth.IBluetoothManager`) via `cmd bluetooth_manager`, `dumpsys bluetooth_manager`, and `service call bluetooth_manager`.

---

## 2. Bluetooth Platform Classification & Capability Matrix

Android does **not** expose a standard Linux BlueZ socket stack (`/dev/hci0`, `hciconfig`, `l2ping`) to userspace by default. Instead, Bluetooth is managed at the kernel/HAL level by Qualcomm/Android Bluetooth stack. Therefore, the Bluetooth tooling is implemented as an **Android Bluetooth Arsenal**.

### Capability Matrix

| Capability | Status | Implementation Mechanism |
| :--- | :---: | :--- |
| **Bluetooth Framework** | ✅ | `android.bluetooth.IBluetoothManager` |
| **Bluetooth Manager Service** | ✅ | `dumpsys bluetooth_manager` / `cmd bluetooth_manager` |
| **Enable/Disable Adapter** | ✅ | `cmd bluetooth_manager enable` / `disable` / `enableBle` |
| **Read Controller Info** | ✅ | `dumpsys bluetooth_manager` (`HCI ControllerImpl`) |
| **Read Advertising Capabilities** | ✅ | Extracted from controller dumpsys (`le_number_supported_advertising_sets`) |
| **Read PAN State** | ✅ | `shim::legacy::pan` & `bt-pan` interface |
| **Read HID State** | ✅ | `shim::legacy::hid` & `HID_HOST` profile inspection |
| **Read A2DP / Codecs** | ✅ | `A2dpOffloadEnabled` & `a2dp_source_offload_capability_mask` |
| **Read Known & Bonded Devices** | ✅ | `BluetoothRemoteDevices` & `shim::record` parser |
| **Bluetooth Service Discovery** | ✅ | `Enabled Profile Services` & SDP dumpsys |
| **BLE Multi-Advertising** | ✅ (16 sets) | Up to 16 concurrent advertising sets supported |
| **Linux BlueZ / hciconfig** | ❌ | Not exposed natively on standard Android kernels |
| **Raw L2CAP Ping / Packet Capture** | ❌ | Requires custom external HCI adapter or BlueZ kernel patch |

---

## 3. Critical Rules for Agents

> [!IMPORTANT]
> 1. **DO NOT MODIFY `usb_gadget/mass_storage_manager.sh`**: The existing Mass Storage script is fully working and verified. Keep it untouched. `launcher.sh` calls `usb_gadget/mass_storage_manager.sh` directly.
> 2. **ConfigFS UDC Handling**: You **MUST unbind UDC** with `echo none > /config/usb_gadget/g1/UDC` before adding or removing symlinks in `configs/b.1/`. After changing links, rebind to `a600000.dwc3`.
> 3. **Consolidated HID Controller (`usb_gadget/hid.sh`)**: Keyboard and Pointer (touchpad/mouse) are consolidated into `usb_gadget/hid.sh` using dynamic device discovery (`cat $G/functions/hid.*/dev` -> `/dev/hidg*`).
> 4. **Shebang Preservation**: Do NOT modify shebangs in `launcher.sh` or core gadget scripts in a way that breaks DroidSpaces Arch Linux execution.
> 5. **Self-Contained & Clean Exit**: Every script must support both non-interactive execution (`start`, `stop`, `status`) and interactive UI. No background processes or dangling symlinks should remain after stopping a module.
> 6. **Hardware Endpoint Limits (Avoid Over-Stacking)**: Qualcomm DWC3 UDC controller has strict physical endpoint limits. Never link more than 2 lightweight functions simultaneously (e.g., RNDIS + KB is safe; do NOT stack Mass Storage + UVC + RNDIS + HID together), as exhausting hardware endpoints triggers a Qualcomm kernel panic/reboot. Test features in isolation.

---

## 4. Directory Structure

```
hard-tools/
├── AGENTS.md                  # This developer & agent guide
├── aim.md / features.md       # Feature roadmap and catalogs
├── kernel.config              # Active kernel build configuration
├── launcher.sh                # Interactive master TUI menu (only script in root)
├── .agents/                   # Operational snapshots & capability matrices
├── bluetooth/                 # Android Bluetooth Arsenal (Rooted Termux / Native)
│   ├── bt_arsenal.sh          # Unified Bluetooth Arsenal & BlueZ fallback
│   ├── bt-status              # Live status, power, MAC, uptime & connected device
│   ├── bt-status-fast         # Sub-millisecond state via Binder Fast Path (TXN 3/6/7)
│   ├── bt-toggle              # Power & mode switch (on, off, ble-on, reset, wait)
│   ├── bt-discovery           # Discovery and inquiry lifecycle status & controller
│   ├── bt-paired              # Fast paired & bonded device inventory table
│   ├── bt-events              # Real-time stack event stream (SCAN, ACL, SDP, RFCOMM)
│   ├── bt-reset               # Soft recovery & verified adapter power cycle
│   ├── bt-scan                # Live scanner telemetry, active clients & start/stop stream
│   ├── bt-info                # HCI/LMP versions, manufacturer & 16-set BLE specs
│   ├── bt-services            # Advertised services and UUID discovery per device
│   ├── bt-security            # Security auditor (Link key types, MITM, P-256 SC)
│   ├── bt-audio               # Audio stack, active sink routing & DSP offload mask
│   ├── bt-profiles            # Registered services (GATT, A2DP, HID, PAN, etc.)
│   ├── bt-devices             # Known & bonded devices, CoD, and link key types
│   ├── bt-device-info         # Deep per-device reconnaissance, UUIDs & policies
│   ├── bt-pan                 # Personal Area Network (NAP/PANU) & bt-pan state
│   ├── bt-pan-status          # Dedicated PAN interface and gateway status
│   ├── bt-codecs              # Hi-Res audio codecs (LDAC, aptX HD, AAC, SBC, LC3)
│   ├── bt-ble-info            # BLE 5.0+ multi-advertising specs and buffer limits
│   ├── bt-ble-clients         # Active BLE scanner client applications and filters
│   ├── bt-binder-map          # Automated Binder transaction enumerator & mapper
│   └── bt-watch               # Real-time 2s refresh activity monitor
├── usb_gadget/                # Core USB Gadget Engines & Controllers
│   ├── mass_storage_manager.sh# [DO NOT MODIFY] Working USB Mass Storage manager
│   ├── hid.sh                 # Consolidated USB HID Controller (Keyboard, Touchpad, Jiggler)
│   ├── chameleon.sh           # USB Chameleon: Dynamic VID/PID & Descriptor Cloner
│   ├── composite.sh           # Composite Multi-Gadget Stacking Engine (Ghost Drive, Auto-Pwn)
│   ├── badusb.sh              # Rogue gateway, aggressive DHCP hijack & captive portal
│   ├── rndis.sh               # RNDIS Ethernet + DHCP/DNS router
│   ├── uvc.sh                 # UVC USB Webcam gadget
│   ├── adb.sh                 # ADB gadget mode switch
│   └── mtp_ptp.sh             # MTP/PTP media transfer gadget
├── network/                   # Network Filters & Diagnostics
│   ├── netfilter.sh           # Iptables NAT/redirection, packet capture & Wireshark streamer
│   └── wifi_diagnostics.sh    # Wi-Fi capability assessment
├── operator/                  # Operator Tooling & Recon
│   ├── recon.sh               # System, USB, and network discovery
│   ├── session.sh             # Terminal session recorder
│   └── ducky.sh               # Hak5 DuckyScript 3.0 multi-OS payload runner
├── lib/                       # Central Shared Helper Libraries
│   ├── utils.sh               # Helpers (UDC, ConfigFS, colors, logging)
│   ├── hid_keymap.sh          # 104-key USB keycode & modifier mapping
│   ├── hid_touch.sh           # Precision Touchpad digitizer engine
│   ├── hid_engine.py          # Python HID engine & Ducky 3.0 parser with typing jitter
│   └── rogue_portal.py        # Multi-template captive portal & credential logger
├── payloads/                  # DuckyScript payloads (.duck)
│   ├── windows/               # Windows staged payloads (Recon, Wi-Fi, UAC)
│   ├── linux/                 # Linux staged payloads (Recon, SSH, Sudo)
│   └── macos/                 # macOS staged payloads (Recon, Spotlight, Wi-Fi)
├── config/                    # Configuration templates & stock descriptor backup
└── images/                    # Local mass storage disk images
```

---

## 5. Status of Features

| Feature | Script / Subsystem | Environment | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Mass Storage** | `usb_gadget/mass_storage_manager.sh` | DroidSpaces | ✅ Done | Working great. DO NOT MODIFY. |
| **USB HID Controller** | `usb_gadget/hid.sh` | DroidSpaces | ✅ Done | Dynamic mapping, 8-byte KB, 12-byte pointer, Jiggler, Ducky. |
| **USB Chameleon** | `usb_gadget/chameleon.sh` | DroidSpaces | ✅ Done | Dynamic VID/PID & localized descriptor spoofing with stock backup. |
| **Composite Engine** | `usb_gadget/composite.sh` | DroidSpaces | ✅ Done | Synchronized multi-gadget profiles: Ghost Drive, Stealth Jiggler, Auto-Pwn, Full Arsenal. |
| **DuckyScript 3.0 Suite** | `operator/ducky.sh` | DroidSpaces | ✅ Done | Multi-OS curated payload matrix with anti-EDR human keystroke jitter. |
| **BadUSB Rogue Gateway** | `usb_gadget/badusb.sh` | DroidSpaces | ✅ Done | RFC Option 3/6/121/249/252 route hijacking & multi-template captive portal. |
| **RNDIS Ethernet** | `usb_gadget/rndis.sh` | DroidSpaces | ✅ Done | Uses `rndis.rndis` + `dnsmasq`. |
| **Netfilter & Sniff** | `network/netfilter.sh` | DroidSpaces | ✅ Done | Port redirection, packet sniffing & real-time remote Wireshark bridge. |
| **UVC Webcam** | `usb_gadget/uvc.sh` | DroidSpaces | ✅ Done | `uvc.0` descriptor & test feed. |
| **ADB Gadget** | `usb_gadget/adb.sh` | DroidSpaces | ✅ Done | Controls `ffs.adb`. |
| **MTP / PTP** | `usb_gadget/mtp_ptp.sh` | DroidSpaces | ✅ Done | `ffs.mtp` & `ffs.ptp` mode. |
| **Android BT Arsenal** | `bluetooth/bt-*` | Rooted Termux | ✅ Done | Full status, toggle, codecs, profiles, devices, PAN, watch. |
| **Bluetooth Suite** | `bluetooth/bt_arsenal.sh` | Dual Runtime | ✅ Done | Bridges Android Bluetooth Arsenal & BlueZ stack. |
| **Wi-Fi Diagnostics** | `network/wifi_diagnostics.sh` | DroidSpaces | ✅ Done | Automated wireless assessment. |
| **Recon & Session** | `operator/recon.sh`, `session.sh`| DroidSpaces | ✅ Done | System discovery & session logging. |
| **Master Launcher** | `launcher.sh` | Dual Runtime | ✅ Done | Unified menu dashboard with live module status indicators. |

---

## 6. Android Bluetooth Arsenal Usage & Observability Engine

### Core Utilities Overview
- `bluetooth/bt-status` : Real-time power state, adapter MAC address, uptime, paired device count, and active A2DP/HFP sinks. Supports `--json`, `--raw`, and `--quiet`.
- `bluetooth/bt-status-fast` : Sub-millisecond state querying via direct Binder fast path (`service call bluetooth_manager 3/6/7`).
- `bluetooth/bt-toggle [on|off|toggle|ble-on|ble-off|reset|wait-on|wait-off]` : High-speed adapter power manipulation via `cmd bluetooth_manager`.
- `bluetooth/bt-reset` : Soft recovery & verified power cycle with Binder-level state convergence.
- `bluetooth/bt-discovery [status|start|stop]` : Discovery and inquiry lifecycle status & controller.
- `bluetooth/bt-paired` : Clean, fast tabular bonded device inventory (`Name | MAC | Transport | CoD`).
- `bluetooth/bt-devices [-v|--verbose] [-j|--json]` : Parsed inventory of bonded devices with MAC, class of device (CoD), transport types, and link keys.
- `bluetooth/bt-device-info <MAC|KEYWORD>` : Deep reconnaissance on a specific target device: Class of Device (CoD), security/link key types, 16-digit MITM auth, advertised profile UUIDs, and connection policies.
- `bluetooth/bt-services [MAC|KEYWORD]` : Advertised services and standard UUID translator (A2DP, AVRCP, HFP, HID, SPP, PAN, FastPair).
- `bluetooth/bt-security [MAC|KEYWORD]` : Link-layer security auditor classifying MITM protection, P-256 Secure Connections, and link keys.
- `bluetooth/bt-scan [-w|--watch] [interval]` : Flagship scanner telemetry tracking registered client packages (e.g. GMS Nearby Fast Pair), scan filters, and live start/stop event streams from `shim::btm`.
- `bluetooth/bt-events [-f|--follow] [count]` : Real-time Bluetooth stack event stream (SCAN, ACL connections, SDP discoveries, RFCOMM channels).
- `bluetooth/bt-info` : Complete HCI/LMP hardware inspection, Qualcomm chipset verification, and 16-set BLE advertising parameters.
- `bluetooth/bt-ble-info` : BLE 5.0+ multi-advertising specs, extended payloads (1650B), and privacy list limits.
- `bluetooth/bt-ble-clients` : Registered BLE scanner client applications, mode distribution, and scan filters.
- `bluetooth/bt-profiles` : Active subsystem inspection (GATT, A2DP, AVRCP, HID Host, PAN, MAP, PBAP, SAP).
- `bluetooth/bt-pan` / `bt-pan-status` : Personal Area Network (NAP/PANU) state and Linux kernel `bt-pan` interface monitor.
- `bluetooth/bt-codecs` / `bt-audio` : High-resolution audio codec matrix (LDAC, aptX HD, aptX, AAC, SBC, LC3, LHDC), active audio sink routing, and DSP hardware offload mask.
- `bluetooth/bt-binder-map [service] [max_txn]` : Automated Binder transaction code enumerator and parcel response classifier.
- `bluetooth/bt-watch [interval]` : Continuous ANSI live dashboard monitoring Bluetooth transactions.

### Binder Fast Path Mapping (`android.bluetooth.IBluetoothManager`)
- `TXN 03`: `getState()` -> `0x0c` (12 = `STATE_ON`)
- `TXN 06`: `isEnabled()` -> `0x01` (true)
- `TXN 07`: `isBleScanAlwaysAvailable()` -> `0x01` (true)
- `TXN 19`: `getAdapter()` -> returns active `IBluetooth` Binder token reference.
