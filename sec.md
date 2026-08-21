# sec.md – Low-Level Hardware, Kernel & System Security Capabilities

This document details the **architectural, kernel-level, and hardware security capabilities** available on this rooted environment (**Xiaomi POCO X6 5G** / Qualcomm Snapdragon 7s Gen 2 `SM7435` / **Linux 5.10.252-Zen-Itsu+** / **Android 16 API 36** / **KernelSU** / **DroidSpaces Arch Linux**).

It focuses strictly on **low-level, deterministic capabilities** exposed by the hardware controller, Linux kernel subsystems, Android framework IPC, and networking stack—excluding high-level wrappers or trivial scripts.

---

## 1. Architectural Overview & Execution Domains

```
+----------------------------------------------------------------------------------------------------+
|                                    HARD-TOOLS SYSTEM MATRIX                                        |
+------------------------------------+----------------------------------+----------------------------+
|   1. LINUX KERNEL & HARDWARE       |   2. ANDROID FRAMEWORK & BINDER  |   3. DROIDSPACES ARCH      |
|   (Qualcomm SM7435 / Zen-Itsu+)    |   (Modular APEX / Android 16)    |   (Namespaces & Tooling)   |
+------------------------------------+----------------------------------+----------------------------+
| • Kernel eBPF Subsystem (JIT ON)   | • Android Bluetooth APEX         | • Arch Linux RootFS        |
| • Kprobes & Ftrace Subsystems      | • Binder IPC Tracing & Injection | • Cgroups v2 & Namespaces  |
| • Qualcomm DWC3 USB UDC Controller | • dumpsys / ServiceManager IPC   | • Python HID Engines       |
| • Netfilter / Xtables / NFQUEUE    | • HAL Inspection (AIDL / HIDL)   | • Network Tap & Wireshark  |
| • Raw AF_PACKET Sockets            | • BTSnoop HCI Hardware Tap       | • Docker Container Engine  |
| • UHID /dev/uhid Device Node       | • SELinux Policy & KernelSU      | • DuckyScript 3.0 Jitter   |
+------------------------------------+----------------------------------+----------------------------+
```

---

## 2. Kernel & Low-Level System Instrumentation

### 2.1 eBPF (Extended Berkeley Packet Filter) Engine
* **Kernel Configuration**:
  * `CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`, `CONFIG_BPF_JIT_ALWAYS_ON=y`, `CONFIG_BPF_JIT_DEFAULT_ON=y`
* **Low-Level Capabilities**:
  * **Kernel Tracing & Hooking**: Attach eBPF programs to tracepoints, raw tracepoints, and kprobes without kernel recompilation.
  * **Network Socket Filtering (TC & XDP)**: Run in-kernel packet inspection and filtering at the Traffic Control (TC) ingress/egress layers.
  * **Syscall Monitoring**: Intercept and log file operations, network connections, process spawns, and privilege transitions in real time with minimal overhead.

### 2.2 Dynamic Kernel Instrumentation (`kprobes` & `ftrace`)
* **Kernel Configuration**:
  * `CONFIG_KPROBES=y`, `CONFIG_PERF_EVENTS=y`
* **Tracing Nodes**:
  * `/sys/kernel/debug/tracing/` (`trace`, `trace_pipe`, `available_events`, `set_ftrace_filter`)
  * `/proc/kallsyms` (Full symbol table accessible via root)
* **Capabilities**:
  * **Function Tracing**: Trace any non-inlined kernel function execution timing and call graphs.
  * **Hardware Performance Counters**: Query CPU performance monitors (instructions, cache misses, branch mispredictions) via `perf_event_open`.

---

## 3. Network Traffic Inspection & Packet Interception

> **Scope Note**: No external USB Wi-Fi dongles required. All network monitoring operates on internal interfaces (`wlan0`, `rmnet_data*`, `usb0`, `rndis0`, `ap0`, `p2p0`, `tun0`, `dummy0`).

### 3.1 Raw Layer-2 / Layer-3 Packet Capture (`AF_PACKET`)
* **Underlying Technology**: Direct `AF_PACKET` raw sockets, `libpcap`, and `tcpdump` with kernel ring buffer (`TPACKET_V3`).
* **Capabilities**:
  * **Promiscuous Interface Sniffing**: Capture all unicast, multicast, and broadcast frames traversing active local interfaces (`wlan0`, `usb0`, `ap0`).
  * **PCAP Live Streamer**: Pipe live capture streams directly to remote Wireshark instances over SSH/Netcat:
    ```bash
    tcpdump -i wlan0 -U -s 0 -w - not port 22 | nc -l -p 9999
    ```
  * **ARP / DHCP / DNS Telemetry**: Real-time passive extraction of LAN hostnames, MAC vendor prefixes, DHCP requests, and plaintext DNS lookups.

### 3.2 Netfilter & Inline Packet Mangling
* **Kernel Configuration**:
  * `CONFIG_NETFILTER=y`, `CONFIG_NETFILTER_ADVANCED=y`, `CONFIG_NETFILTER_XT_TARGET_REDIRECT=y`, `CONFIG_NETFILTER_NETLINK_QUEUE=y`, `CONFIG_NETFILTER_NETLINK_LOG=y`
* **Capabilities**:
  * **Transparent Port Redirection**: Redirect outbound HTTP/HTTPS/DNS traffic from connected USB/Wi-Fi clients to local inspection proxies via `iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080`.
  * **NFQUEUE Userspace Processing**: Intercept network packets in userspace (via `libnetfilter_queue`), inspect payloads, alter bytes, or drop packets dynamically.
  * **Bandwidth & Socket Attribution (`xt_qtaguid`)**: Correlate raw network flows with specific Android Application UIDs.

---

## 4. Bluetooth Protocol Stack & RF Reconnaissance

### 4.1 HCI Hardware Snoop Logging
* **Mechanism**: Qualcomm Bluetooth HAL Snoop Engine (`vendor.bluetooth-1-0-qti`).
* **Configuration**:
  ```bash
  setprop persist.bluetooth.btsnoopdefaultmode full
  setprop persist.bluetooth.btsnooppath /sdcard/btsnoop_hci.log
  ```
* **Capabilities**:
  * **Full HCI Packet Capture**: Logs 100% of raw Bluetooth baseband traffic (HCI Commands, Events, ACL Data, SCO Voice, and ISO LeAudio frames).
  * **Wireshark Analysis**: Open the resulting `btsnoop_hci.log` directly in Wireshark to dissect L2CAP, SDP, ATT, SMP, and RFCOMM protocol exchanges.

### 4.2 Bluetooth HID Device Profile (Keystroke & Input Injection)
* **Underlying Technology**: `android.bluetooth.BluetoothHidDevice` + `btif_hd.cc` + `/dev/uhid` (Misc device `10, 239`).
* **Capabilities**:
  * **Wireless Hardware Keyboard Emulation**: Turns phone into a trusted Bluetooth Physical Keyboard.
  * **Full 8-Byte Report Descriptor**: Supports all standard USB HID keys, modifiers, and scan codes.
  * **Hak5 DuckyScript 3.0 Runner**: Executes wireless keystroke payloads over Bluetooth without physical cables.
  * **24/7 Background Persistence**: Operates as a Foreground Service (`foregroundServiceType="connectedDevice"`).

### 4.3 Bluetooth Reconnaissance & Security Auditing
* **Stack Inspection Points**: `dumpsys bluetooth_manager`, `shim::record`, `/data/misc/bluedroid/bt_config.conf`.
* **Capabilities**:
  * **Link-Layer Security Profiling**: Extracts link key types (`UNAUTH_COMB`, `AUTH_COMB_P_256`), MITM protection flags, and Secure Connections status per paired device.
  * **BLE Multi-Advertising (16 Concurrent Sets)**: Transmit up to 16 distinct BLE beacons simultaneously with extended advertisement payloads (up to 1650 bytes).
  * **Active Profile Mapping**: Audit active device capabilities (A2DP DSP Offload masks, HID Host, PAN Gateway, GATT clients).

---

## 5. USB Hardware Gadget & ConfigFS Subsystem

### 5.1 Qualcomm DWC3 UDC Controller (`a600000.dwc3`)
* **Gadget Directory**: `/config/usb_gadget/g1/`
* **Supported Function Drivers**:
  * `mass_storage.0` (USB Flash & CD-ROM ISO Emulation)
  * `hid.keyboard` / `hid.touchpad` (USB HID Input Devices)
  * `rndis.rndis` (USB RNDIS / Ethernet Gateway)
  * `uvc.0` (USB Video Class Webcam)
  * `ffs.adb`, `ffs.mtp`, `ffs.ptp` (FunctionFS Android Subsystems)

### 5.2 USB Chameleon (Hardware Descriptor & Identity Spoofing)
* **Capabilities**:
  * **VID/PID & Serial Spoofing**: Dynamic rewrites of `idVendor`, `idProduct`, `iManufacturer`, and `iProduct` to impersonate legitimate hardware vendors (Apple, Logitech, Dell, Microsoft, SanDisk) and bypass enterprise endpoint controls.
  * **Composite Stacking**: Combine multiple functions (e.g. Mass Storage + RNDIS Network + Virtual Keyboard) into a single USB configuration.

---

## 6. Android IPC, Binder & OS Subsystem Research

### 6.1 Binder IPC Interception & Mapping
* **Mechanism**: Direct communication with `servicemanager` and `IBluetoothManager` via `/system/bin/service` and `/system/bin/cmd`.
* **Capabilities**:
  * **Transaction Enumerator (`bt-binder-map`)**: Enumerate AIDL transaction codes across registered system services.
  * **Fast-Path Status Querying**: Sub-millisecond state queries directly via Binder transactions (e.g. `service call bluetooth_manager 3` for instant power state).

### 6.2 SELinux Policy & KernelSU Sandbox
* **Status**: Elevated context `u:r:ksu:s0` (UID 0).
* **Capabilities**:
  * **Policy Inspection**: Read active policy rules via `/sys/fs/selinux/`.
  * **AVC Audit Monitoring**: Live monitoring of access vector cache denials via `dmesg | grep avc`.
  * **Namespace Transition**: Seamless switching between Android init namespaces, Termux environments, and DroidSpaces container mounts.

---

## 7. Capability Summary Matrix

| Domain | Low-Level Technology | Hardware / Driver Node | Status | Primary Security Research Use |
| :--- | :--- | :--- | :---: | :--- |
| **Kernel Tracing** | eBPF + Kprobes + Perf | `/sys/kernel/debug/tracing` | ✅ Active | Kernel observability, syscall interception & socket filtering. |
| **Network Sniffing** | Raw `AF_PACKET` Sockets | `wlan0`, `usb0`, `ap0` | ✅ Active | Layer 2/3 packet dissection, PCAP streaming & DNS analysis. |
| **Traffic Interception**| Netfilter + NFQUEUE | Linux `xtables` / `iptables` | ✅ Active | Inline packet inspection, transparent NAT & port redirection. |
| **Bluetooth HID** | Android HID API + UHID | `/dev/uhid` | ✅ Active | Wireless Bluetooth keyboard injection & DuckyScript automation. |
| **Bluetooth Telemetry**| BTSnoop + APEX IPC | Qualcomm HAL / APEX | ✅ Active | HCI packet capture, BLE advertising & security grading. |
| **USB Gadget Engine** | Linux ConfigFS + DWC3 | `/config/usb_gadget/g1` | ✅ Active | USB Mass Storage, Virtual HID, RNDIS Gateway, Chameleon. |
| **IPC Reverse-Eng** | Android Binder Subsystem | `/dev/binder`, `dumpsys` | ✅ Active | AIDL transaction mapping, service state fast-path querying. |
| **Container Engine** | Linux Namespaces / cgroups | DroidSpaces Arch Linux | ✅ Active | Full Linux userland execution, systemd services & Docker. |
