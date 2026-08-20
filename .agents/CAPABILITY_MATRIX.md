# Hard-Tools Platform Capability Matrix

This document records the exact, tested capabilities of the Android kernel, DroidSpaces container, and USB Gadget subsystem on this hardware platform.

---

## 1. Subsystem Verification Status

| Subsystem / Feature | Driver / Node | Verification Status | Confidence | Technical Details |
| :--- | :--- | :--- | :--- | :--- |
| **USB Keyboard** | `hid.keyboard` -> `/dev/hidg1` | ✅ **VERIFIED** | 100% | Standard 8-byte boot keyboard report descriptor. 104-key typing, hotkeys. |
| **USB Relative Pointer** | `hid.touchpad` -> `/dev/hidg2` | ✅ **VERIFIED** | 100% | Report ID `0x01` (12-byte report: buttons, signed int8 dX/dY, padding). |
| **USB Absolute Digitizer** | `hid.touchpad` -> `/dev/hidg2` | ✅ **VERIFIED** | 100% | Report ID `0x04` (flags, 16-bit X/Y `0..3528`, scan time, contact count). |
| **USB Mass Storage** | `mass_storage.0` | ✅ **VERIFIED** | 100% | Managed via `scripts/mass_storage_manager.sh`. Backing `.img` formatted as FAT32/exFAT. |
| **USB RNDIS Ethernet** | `rndis.rndis` -> `usb0` | ✅ **VERIFIED** | 100% | Interface `usb0` active, `dnsmasq` DHCP server leasing `192.168.42.x`, ARP verified. |
| **USB UVC Webcam** | `uvc.0` -> `/dev/video2` | ✅ **VERIFIED** | 95% | UVC output sink `/dev/video2` (group `video`) generated on bind. |
| **USB Composite Modes** | Multiple symlinks in `b.1/` | ✅ **VERIFIED** | 100% | Multi-function configurations (HID + Storage + RNDIS + UVC) active simultaneously. |
| **TUN / TAP Networking** | `/dev/net/tun` | ✅ **VERIFIED** | 100% | Character device active; virtual `tun` interfaces instantiate cleanly. |
| **Network Namespaces** | `unshare -n` | ✅ **VERIFIED** | 100% | `CONFIG_NET_NS=y`. Isolated network namespaces functional. |
| **Packet Filtering** | `iptables-legacy` | ✅ **VERIFIED** | 100% | Native `xtables` active. Standard Android filter, nat, and mangle tables functional. |
| **eBPF Subsystem** | `CONFIG_BPF_SYSCALL=y` | ✅ **AVAILABLE** | 90% | BPF syscall and JIT enabled in kernel config. |
| **Bluetooth Arsenal** | BlueZ + Android HAL | ⚠️ **PARTIAL** | 80% | BlueZ tools (`bluetoothctl`, `l2ping`) available; Android framework access via root `cmd/dumpsys`. |
| **Wi-Fi Modes** | Qualcomm `qcacld-3.0` | ⚠️ **PARTIAL** | 80% | `managed`, `AP`, `monitor`, `P2P`, `NAN` advertised; FullMAC DSP enforces managed mode. |

---

## 2. Hardware Identifiers & Controller Map

- **UDC Controller**: `a600000.dwc3` (Qualcomm SuperSpeed DWC3 USB Controller)
- **ConfigFS Root**: `/config/usb_gadget/g1`
- **Active Config**: `/config/usb_gadget/g1/configs/b.1`
- **Functions Root**: `/config/usb_gadget/g1/functions`
- **Wi-Fi PHY**: `phy#0` (Qualcomm WCN subsystem)
- **Shared Storage**: `/storage/emulated/0/hard-tools/`
