#!/data/data/com.termux/files/usr/bin/bash
#
# hard-tools: scripts/bt_arsenal.sh
# Unified Bluetooth Arsenal (Android Bluetooth Framework & BlueZ Stack)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
BT_DIR="$(cd "${SCRIPT_DIR}/../bluetooth" && pwd)"
source "${LIB_DIR}/utils.sh"

HCI_DEV="hci0"

check_bt_interface() {
    if ! hciconfig "$HCI_DEV" >/dev/null 2>&1; then
        local dev
        dev=$(hciconfig 2>/dev/null | grep -o "hci[0-9]" | head -n1 || true)
        if [[ -n "$dev" ]]; then
            HCI_DEV="$dev"
        else
            log_warn "No BlueZ Linux HCI controller detected (/dev/hci0)."
            log_info "Running on Android native Bluetooth stack via Android Bluetooth Arsenal."
            return 1
        fi
    fi
    return 0
}

# Android Bluetooth Arsenal wrappers
call_bt_tool() {
    local tool="$1"
    shift
    if [[ -x "${BT_DIR}/${tool}" ]]; then
        "${BT_DIR}/${tool}" "$@"
    elif [[ -f "${BT_DIR}/${tool}" ]]; then
        bash "${BT_DIR}/${tool}" "$@"
    else
        log_error "Tool ${BT_DIR}/${tool} not found."
    fi
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
    print_header "Spoof Bluetooth Device Name (HCI)"
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
    call_bt_tool "bt-status"
}

menu() {
    while true; do
        clear 2>/dev/null || true
        call_bt_tool "bt-status-fast"
        echo
        echo -e "  ${COLOR_BOLD}Android Bluetooth Arsenal (Native Observability):${COLOR_RESET}"
        echo "   1) Real-Time Scan Telemetry & Clients   (bt-scan)"
        echo "   2) Deep Device Reconnaissance & UUIDs   (bt-device-info)"
        echo "   3) Toggle Bluetooth Power / BLE Mode    (bt-toggle)"
        echo "   4) Full Bluetooth Status & Sink Info    (bt-status)"
        echo "   5) Hardware & Advertising Specs         (bt-info)"
        echo "   6) Active Profiles & Subsystems         (bt-profiles)"
        echo "   7) Known & Bonded Remote Devices        (bt-devices)"
        echo "   8) PAN Network & Tethering State        (bt-pan)"
        echo "   9) Audio Codecs & A2DP Offload Engine   (bt-codecs)"
        echo "  10) Real-Time Live Bluetooth Monitor     (bt-watch)"
        echo
        echo -e "  ${COLOR_BOLD}BlueZ Linux Stack (Requires raw /dev/hci0 adapter):${COLOR_RESET}"
        echo "  11) Classic Device Scan (hcitool scan)"
        echo "  12) BLE Scan (hcitool lescan)"
        echo "  13) L2CAP Ping Stress Test (l2ping)"
        echo "  14) Spoof HCI Device Name"
        echo "  15) Start BLE Advertisement Beacon"
        echo
        echo "   0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1)
                echo "Scan Mode: [1] Snapshot View  [2] Live Follow Stream"
                read -rp "Select [1/2]: " sopt
                [[ "$sopt" == "2" ]] && call_bt_tool "bt-scan" -f || call_bt_tool "bt-scan"
                press_enter ;;
            2)
                read -rp "Enter Target Device MAC or Name: " dmac
                call_bt_tool "bt-device-info" "$dmac"
                press_enter ;;
            3)
                echo "Toggle Options: [1] Toggle [2] Enable [3] Disable [4] BLE-Only [5] Factory Reset"
                read -rp "Select [1-5]: " topt
                case "$topt" in
                    1) call_bt_tool "bt-toggle" toggle ;;
                    2) call_bt_tool "bt-toggle" on ;;
                    3) call_bt_tool "bt-toggle" off ;;
                    4) call_bt_tool "bt-toggle" ble-on ;;
                    5) call_bt_tool "bt-toggle" reset ;;
                esac
                press_enter ;;
            4) call_bt_tool "bt-status"; press_enter ;;
            5) call_bt_tool "bt-info"; press_enter ;;
            6) call_bt_tool "bt-profiles"; press_enter ;;
            7)
                echo "Display: [1] Standard Table  [2] Verbose with Link Keys"
                read -rp "Select [1/2]: " dopt
                [[ "$dopt" == "2" ]] && call_bt_tool "bt-devices" -v || call_bt_tool "bt-devices"
                press_enter ;;
            8) call_bt_tool "bt-pan"; press_enter ;;
            9) call_bt_tool "bt-codecs"; press_enter ;;
            10) call_bt_tool "bt-watch" ;;
            11) bt_scan; press_enter ;;
            12) ble_scan; press_enter ;;
            13) l2ping_flood; press_enter ;;
            14) bt_spoof_name; press_enter ;;
            15) ble_beacon_spam; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    fast)     call_bt_tool "bt-status-fast" ;;
    scan)     call_bt_tool "bt-scan" "${2:-}" ;;
    devinfo)  call_bt_tool "bt-device-info" "${2:-}" ;;
    status)   call_bt_tool "bt-status" ;;
    toggle)   call_bt_tool "bt-toggle" "${2:-toggle}" ;;
    info)     call_bt_tool "bt-info" ;;
    profiles) call_bt_tool "bt-profiles" ;;
    devices)  call_bt_tool "bt-devices" "${2:-}" ;;
    pan)      call_bt_tool "bt-pan" ;;
    codecs)   call_bt_tool "bt-codecs" ;;
    watch)    call_bt_tool "bt-watch" "${2:-2}" ;;
    bluez-scan)   bt_scan ;;
    bluez-lescan) ble_scan ;;
    flood)        l2ping_flood ;;
    menu|"")      menu ;;
    *) echo "Usage: $0 {fast|scan|devinfo|status|toggle|info|profiles|devices|pan|codecs|watch|menu}" ;;
esac
