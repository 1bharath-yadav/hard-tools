# Agent Operational Protocols & Workflow Rules

This document specifies the operational rules, safety protocols, and technical procedures that all agents and developers must adhere to when interacting with the `hard-tools` environment.

---

## 1. Golden Rules for Agents

> [!CRITICAL]
> 1. **DO NOT MODIFY `mass_storage_manager.sh`**: The USB Mass Storage manager is fully verified and stable. It must remain untouched. All integrations should call it directly.
> 2. **ConfigFS UDC Handling**: You **MUST ALWAYS unbind UDC** with `echo none > /config/usb_gadget/g1/UDC` before adding or removing symlinks in `configs/b.1/`. Modifying links while UDC is bound causes kernel `EINVAL` (-22).
> 3. **Preserve Existing Functions**: Never delete or `rmdir` pre-existing function directories in `/config/usb_gadget/g1/functions/` (such as `hid.keyboard`, `hid.touchpad`, `mass_storage.0`, `rndis.rndis`, `ffs.adb`, etc.). Only manipulate symlinks in `configs/b.1/`.
> 4. **Clean Process Teardown**: Scripts that spawn background processes (`dnsmasq`, `jiggler`, `ffmpeg`) must write a PID file to `/tmp/` and clean up all background jobs and iptables rules on exit or `stop`.

---

## 2. Dynamic HID Device Discovery

Never hardcode `/dev/hidg0` or `/dev/hidg1`. Always resolve device nodes dynamically by reading the `dev` attribute from the ConfigFS function directory:

```bash
# Example dynamic resolution
KEY_DEV="/dev/hidg$(cat /config/usb_gadget/g1/functions/hid.keyboard/dev | awk -F: '{print $2}')"
TOUCH_DEV="/dev/hidg$(cat /config/usb_gadget/g1/functions/hid.touchpad/dev | awk -F: '{print $2}')"
```

---

## 3. Android USB Restoration Protocol

To return the phone to its standard Android USB state (`mtp,adb`):

```bash
sudo sh -c '
G=/config/usb_gadget/g1
C=$G/configs/b.1
UDC=a600000.dwc3

echo none > "$G/UDC"
rm -f "$C"/hid.* "$C"/rndis.* "$C"/mass_storage.* "$C"/uvc.*

setprop sys.usb.config none
sleep 1
setprop sys.usb.controller "$UDC"
setprop sys.usb.config mtp,adb
'
```

---

## 4. Firewall & Packet Filtering Protocol

- The kernel uses `iptables-legacy` (xtables), not `nftables`.
- All firewall manipulation, NAT rules, and port forwarding rules must use `iptables-legacy` (or the helper in `lib/utils.sh`).
- Always flush created PREROUTING rules upon module termination.
