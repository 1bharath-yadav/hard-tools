# Project Phase Boundaries & Roadmap

```yaml
project: hard-tools
identity:
  interface: [shell, tui]
  philosophy: [local_first, script_driven, terminal_native]
  avoid: [web_ui, backend_services, browser_dependency]

phase_1:
  name: USB Arsenal Infrastructure
  status: COMPLETE
  artifacts:
    - scripts/usb-gadget.sh (HID KB, Touchpad, Digitizer, Jiggler)
    - scripts/mass_storage_manager.sh (FAT32/exFAT drive)
    - scripts/rndis.sh (USB Ethernet + DHCP router)
    - scripts/uvc_webcam.sh (UVC video sink)
    - scripts/composite_gadget.sh (Multi-function configurations)
    - launcher.sh (Master dashboard)

phase_2:
  name: Wireless Capability Assessment
  status: COMPLETE
  artifacts:
    - scripts/wifi_diagnostics.sh
    - .agents/WIFI_CAPABILITY_MATRIX.md

phase_3:
  name: Operator Toolkit & Automation
  status: ACTIVE
  components:
    - bluetooth: BlueZ HCI/BLE discovery & L2ping tooling
    - recon: Local & target USB/network inventory
    - payload_engine: Cross-platform DuckyScript runner
    - session_logger: Timestamped terminal session & artifact recorder
```
