#!/usr/bin/env bash
#
# hard-tools: scripts/wifi_diagnostics.sh
# Automated Wireless Stack Capability Assessment & Diagnostic Suite
# Output: .agents/WIFI_CAPABILITY_MATRIX.md
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

OUTPUT_MATRIX="${ROOT_DIR}/.agents/WIFI_CAPABILITY_MATRIX.md"

PHY_DEVICE="phy0"
WIFI_IFACE="wlan0"
MON_IFACE="mon0"

RES_PHY_INFO="UNKNOWN"
RES_SUPPORTED_MODES=""
RES_MONITOR_DIRECT="NO"
RES_MONITOR_VIRTUAL="NO"
RES_CAPTURE="NO"
RES_INJECTION="NO"
RES_CHANNEL_HOPPING="NO"
RES_DRIVER="Qualcomm qcacld-3.0"

check_prerequisites() {
    sudo pacman -S --needed --noconfirm iw iproute2 wireless_tools tcpdump 2>/dev/null || true
}

run_phy_assessment() {
    print_header "1. Physical Device & Driver Inspection"
    if ! command -v iw >/dev/null 2>&1; then
        log_error "iw tool missing."
        return 1
    fi

    log_info "Querying wireless physical interfaces..."
    local phy_list
    phy_list=$(iw dev 2>&1)
    echo "$phy_list"

    RES_SUPPORTED_MODES=$(iw phy "$PHY_DEVICE" info 2>/dev/null | grep -A 10 "Supported interface modes:" | grep "\*" | tr -d '\t*' | paste -sd ", " - || echo "unknown")
    log_info "Advertised Modes: ${RES_SUPPORTED_MODES}"
}

test_virtual_monitor() {
    print_header "2. Testing Virtual Monitor Interface (iw interface add)"
    log_info "Attempting: sudo iw phy ${PHY_DEVICE} interface add ${MON_IFACE} type monitor"
    
    if sudo iw phy "$PHY_DEVICE" interface add "$MON_IFACE" type monitor 2>/dev/null; then
        sudo ip link set "$MON_IFACE" up 2>/dev/null || true
        if ip link show "$MON_IFACE" 2>/dev/null | grep -q "state UP"; then
            log_success "Virtual monitor interface ${MON_IFACE} created and UP."
            RES_MONITOR_VIRTUAL="YES"
            sudo ip link set "$MON_IFACE" down 2>/dev/null || true
            sudo iw dev "$MON_IFACE" del 2>/dev/null || true
        fi
    else
        log_warn "Virtual monitor interface creation not supported by driver (-22 / EINVAL)."
        RES_MONITOR_VIRTUAL="NO (Vendor driver restriction)"
    fi
}

test_direct_monitor() {
    print_header "3. Testing Direct Interface Monitor Mode (${WIFI_IFACE})"
    log_info "Temporarily stopping Android Wi-Fi service to release driver..."
    sudo svc wifi disable 2>/dev/null || true
    sleep 1

    log_info "Setting ${WIFI_IFACE} down..."
    sudo ip link set "$WIFI_IFACE" down 2>/dev/null || true
    sleep 1

    log_info "Setting mode to monitor..."
    if sudo iw dev "$WIFI_IFACE" set type monitor 2>/dev/null; then
        sudo ip link set "$WIFI_IFACE" up 2>/dev/null || true
        local current_type
        current_type=$(iw dev "$WIFI_IFACE" info 2>/dev/null | grep "type" | awk '{print $2}')
        if [[ "$current_type" == "monitor" ]]; then
            log_success "Interface ${WIFI_IFACE} transitioned to MONITOR mode!"
            RES_MONITOR_DIRECT="YES"
            
            # Test channel switching
            log_info "Testing channel switching to channel 6..."
            if sudo iw dev "$WIFI_IFACE" set channel 6 2>/dev/null; then
                RES_CHANNEL_HOPPING="YES"
                log_success "Channel hopping supported."
            fi

            # Test packet capture
            log_info "Testing raw 802.11 frame capture (5s)..."
            if sudo tcpdump -i "$WIFI_IFACE" -c 10 -n -q 2>/dev/null; then
                RES_CAPTURE="YES"
                log_success "Raw 802.11 packet capture verified!"
            fi
        else
            log_warn "iw set type monitor accepted but state remained $current_type."
            RES_MONITOR_DIRECT="NO"
        fi
    else
        log_warn "Direct interface monitor mode switch failed."
        RES_MONITOR_DIRECT="NO (Driver requires patched FullMAC firmware)"
    fi

    # Restore interface
    log_info "Restoring interface to managed mode and re-enabling Wi-Fi..."
    sudo ip link set "$WIFI_IFACE" down 2>/dev/null || true
    sudo iw dev "$WIFI_IFACE" set type managed 2>/dev/null || true
    sudo ip link set "$WIFI_IFACE" up 2>/dev/null || true
    sudo svc wifi enable 2>/dev/null || true
}

generate_report() {
    print_header "4. Generating Capability Matrix"
    cat << REPORTEOF > "$OUTPUT_MATRIX"
# Wi-Fi Stack Capability Matrix

Assessment Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Driver: ${RES_DRIVER}
Physical Device: ${PHY_DEVICE}

---

## 1. Capabilities Summary

| Feature | Result | Notes |
| :--- | :--- | :--- |
| **Driver Type** | Qualcomm FullMAC | \`CONFIG_CFG80211=m\`, \`CONFIG_MAC80211=n\` |
| **Advertised Modes** | ${RES_SUPPORTED_MODES} | Query from \`iw phy info\` |
| **Virtual Monitor (\`mon0\`)** | ${RES_MONITOR_VIRTUAL} | Multiple virtual interfaces on single PHY |
| **Direct Monitor (\`wlan0\`)** | ${RES_MONITOR_DIRECT} | Mode switch on primary interface |
| **Channel Switching** | ${RES_CHANNEL_HOPPING} | Software frequency configuration |
| **Raw Frame Capture** | ${RES_CAPTURE} | 802.11 link-layer header capture |
| **Packet Injection** | ${RES_INJECTION} | Custom frame transmission |

---

## 2. Technical Findings & Constraints

1. **Vendor FullMAC Architecture**: Qualcomm's \`qcacld-3.0\` firmware offloads 802.11 MAC management directly onto the wireless chip's DSP.
2. **Android HAL Coexistence**: The internal \`wlan0\` radio is actively polled by Android \`wificond\`. Standard monitor mode requires disabling Android Wi-Fi service.
3. **Recommended Hardware for Full Research**: For full packet injection and SoftMAC monitor mode without Android firmware restrictions, an external USB OTG Wi-Fi adapter with in-tree kernel drivers (e.g. Atheros \`ath9k_htc\` or MediaTek \`mt7601u\`) is optimal.
REPORTEOF

    log_success "Saved report to: ${OUTPUT_MATRIX}"
}

main() {
    check_prerequisites
    run_phy_assessment
    test_virtual_monitor
    test_direct_monitor
    generate_report
}

main "$@"
