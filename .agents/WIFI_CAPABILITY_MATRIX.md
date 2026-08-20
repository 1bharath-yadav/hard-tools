# Wi-Fi Stack Capability Matrix

Assessment Timestamp: 2026-08-20T19:00:53Z
Driver: Qualcomm qcacld-3.0
Physical Device: phy0

---

## 1. Capabilities Summary

| Feature | Result | Notes |
| :--- | :--- | :--- |
| **Driver Type** | Qualcomm FullMAC | `CONFIG_CFG80211=m`, `CONFIG_MAC80211=n` |
| **Advertised Modes** |   managed,  AP   monitor,  P2P-client   P2P-GO,  NAN | Query from `iw phy info` |
| **Virtual Monitor (`mon0`)** | NO (Vendor driver restriction) | Multiple virtual interfaces on single PHY |
| **Direct Monitor (`wlan0`)** | NO (Driver requires patched FullMAC firmware) | Mode switch on primary interface |
| **Channel Switching** | NO | Software frequency configuration |
| **Raw Frame Capture** | NO | 802.11 link-layer header capture |
| **Packet Injection** | NO | Custom frame transmission |

---

## 2. Technical Findings & Constraints

1. **Vendor FullMAC Architecture**: Qualcomm's `qcacld-3.0` firmware offloads 802.11 MAC management directly onto the wireless chip's DSP.
2. **Android HAL Coexistence**: The internal `wlan0` radio is actively polled by Android `wificond`. Standard monitor mode requires disabling Android Wi-Fi service.
3. **Recommended Hardware for Full Research**: For full packet injection and SoftMAC monitor mode without Android firmware restrictions, an external USB OTG Wi-Fi adapter with in-tree kernel drivers (e.g. Atheros `ath9k_htc` or MediaTek `mt7601u`) is optimal.
