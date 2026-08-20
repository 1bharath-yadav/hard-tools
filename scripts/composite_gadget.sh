#!/usr/bin/env bash
#
# hard-tools: scripts/composite_gadget.sh
# Multi-Function USB Composite Gadget Controller
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

DEFAULT_IMG="${IMAGES_DIR}/mass_storage.img"

clear_composite() {
    unbind_udc
    unlink_function "hid.keyboard"
    unlink_function "hid.touchpad"
    unlink_function "mass_storage.0"
    unlink_function "rndis.rndis"
    unlink_function "uvc.0"
}

start_hid_storage() {
    print_header "Starting Composite: HID (Keyboard/Touchpad) + Mass Storage"
    clear_composite
    
    # Ensure backing file is configured
    if [[ ! -f "$DEFAULT_IMG" ]]; then
        log_info "Creating default 512MB disk image..."
        sudo dd if=/dev/zero of="$DEFAULT_IMG" bs=1M count=512 status=none
        sudo mkfs.fat -F 32 "$DEFAULT_IMG" >/dev/null 2>&1 || true
    fi
    sudo sh -c "echo '$DEFAULT_IMG' > '${FUNCTIONS_DIR}/mass_storage.0/lun.0/file'" 2>/dev/null || true

    link_function "hid.keyboard" "hid.keyboard"
    link_function "hid.touchpad" "hid.touchpad"
    link_function "mass_storage.0" "mass_storage.0"

    bind_udc
    log_success "Composite Mode ACTIVE: Keyboard + Touchpad + Storage Drive."
}

start_hid_rndis() {
    print_header "Starting Composite: HID (Keyboard/Touchpad) + RNDIS Ethernet"
    clear_composite

    link_function "hid.keyboard" "hid.keyboard"
    link_function "hid.touchpad" "hid.touchpad"
    link_function "rndis.rndis" "rndis.rndis"

    bind_udc
    sleep 1

    # Start network router
    sudo bash "${SCRIPT_DIR}/rndis.sh" start
    log_success "Composite Mode ACTIVE: Keyboard + Touchpad + USB Ethernet."
}

start_hid_storage_rndis() {
    print_header "Starting Composite: HID + Mass Storage + RNDIS Ethernet"
    clear_composite

    if [[ ! -f "$DEFAULT_IMG" ]]; then
        sudo dd if=/dev/zero of="$DEFAULT_IMG" bs=1M count=512 status=none
        sudo mkfs.fat -F 32 "$DEFAULT_IMG" >/dev/null 2>&1 || true
    fi
    sudo sh -c "echo '$DEFAULT_IMG' > '${FUNCTIONS_DIR}/mass_storage.0/lun.0/file'" 2>/dev/null || true

    link_function "hid.keyboard" "hid.keyboard"
    link_function "hid.touchpad" "hid.touchpad"
    link_function "mass_storage.0" "mass_storage.0"
    link_function "rndis.rndis" "rndis.rndis"

    bind_udc
    sleep 1

    sudo bash "${SCRIPT_DIR}/rndis.sh" start
    log_success "Triple Composite Mode ACTIVE: Keyboard + Storage + Network."
}

start_full_arsenal() {
    print_header "Starting FULL Composite Arsenal (HID + Storage + RNDIS + UVC Camera)"
    clear_composite

    if [[ ! -f "$DEFAULT_IMG" ]]; then
        sudo dd if=/dev/zero of="$DEFAULT_IMG" bs=1M count=512 status=none
        sudo mkfs.fat -F 32 "$DEFAULT_IMG" >/dev/null 2>&1 || true
    fi
    sudo sh -c "echo '$DEFAULT_IMG' > '${FUNCTIONS_DIR}/mass_storage.0/lun.0/file'" 2>/dev/null || true

    link_function "hid.keyboard" "hid.keyboard"
    link_function "hid.touchpad" "hid.touchpad"
    link_function "mass_storage.0" "mass_storage.0"
    link_function "rndis.rndis" "rndis.rndis"
    link_function "uvc.0" "uvc.0"

    bind_udc
    sleep 1

    sudo bash "${SCRIPT_DIR}/rndis.sh" start
    log_success "FULL ARSENAL Composite ACTIVE: KB + Mouse + Drive + Ethernet + Camera."
}

stop_all() {
    print_header "Stopping Composite Gadget"
    sudo pkill -f "dnsmasq.*rndis" 2>/dev/null || true
    clear_composite
    log_success "All composite functions stopped and unbound."
}

status() {
    print_header "Active Composite Gadget Configuration"
    echo -e "UDC Controller:  ${COLOR_CYAN}$(get_udc)${COLOR_RESET}"
    echo "Active Linked Functions in ConfigFS:"
    for link in $(sudo ls "${CONFIG_DIR}" 2>/dev/null); do
        if sudo test -L "${CONFIG_DIR}/${link}"; then
            echo -e "  * ${COLOR_GREEN}${link}${COLOR_RESET} -> $(sudo readlink "${CONFIG_DIR}/${link}")"
        fi
    done
    echo
}

menu() {
    while true; do
        print_header "USB Composite Gadget Arsenal"
        status
        echo " 1) HID + Mass Storage Drive"
        echo " 2) HID + RNDIS USB Ethernet"
        echo " 3) HID + Mass Storage + RNDIS Ethernet"
        echo " 4) Full Arsenal (HID + Storage + RNDIS + UVC Camera)"
        echo " 5) Stop / Disconnect Composite Gadget"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start_hid_storage; press_enter ;;
            2) start_hid_rndis; press_enter ;;
            3) start_hid_storage_rndis; press_enter ;;
            4) start_full_arsenal; press_enter ;;
            5) stop_all; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    hid-storage)       start_hid_storage ;;
    hid-rndis)         start_hid_rndis ;;
    hid-storage-rndis) start_hid_storage_rndis ;;
    full)              start_full_arsenal ;;
    stop)              stop_all ;;
    status)            status ;;
    menu|"")           menu ;;
    *) echo "Usage: $0 {hid-storage|hid-rndis|hid-storage-rndis|full|stop|status|menu}" ;;
esac
