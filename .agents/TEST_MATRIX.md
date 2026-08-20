# Subsystem & Hardware Test Matrix

```yaml
usb_gadget:
  hid_keyboard:
    status: VERIFIED
    notes: 8-byte boot keyboard protocol 1
  hid_touchpad:
    status: VERIFIED
    notes: 12-byte report ID 0x01 (relative) + 0x04 (digitizer)
  mass_storage:
    status: VERIFIED
    notes: FAT32 backing image attachment
  rndis_network:
    status: VERIFIED
    notes: Host DHCP lease 192.168.42.x + ARP communication
  uvc_camera:
    status: VERIFIED
    notes: Output video node /dev/video2
  composite_mode:
    status: VERIFIED
    notes: Multi-function symlinks in configs/b.1

networking:
  network_namespace:
    status: VERIFIED
    notes: unshare -n creates isolated network namespace
  tun_tap:
    status: VERIFIED
    notes: /dev/net/tun creates tun/tap interfaces
  iptables_legacy:
    status: VERIFIED
    notes: xtables rules active and operational

wireless:
  chipset_driver:
    status: IDENTIFIED
    notes: Qualcomm qcacld-3.0 (cfg80211 FullMAC)
  monitor_mode:
    status: PENDING_QUALCOMM_ISOLATION_TEST
    notes: Driver advertises monitor mode via iw list
  packet_injection:
    status: UNTESTED
    notes: Requires taking down Android Wi-Fi service first

bluetooth:
  hci_controller:
    status: PENDING_TEST
    notes: BlueZ utilities installed (bluetoothctl, l2ping, hciconfig)
```
