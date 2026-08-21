#!/usr/bin/env bash
#
# hard-tools: usb_gadget/chameleon.sh
# USB Chameleon: Dynamic Descriptor & Hardware Identity Cloner
# Spoofs Vendor/Product IDs and USB descriptors to bypass USB whitelisting & EDR.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
CONFIG_BACKUP_DIR="${ROOT_DIR}/config"
source "${LIB_DIR}/utils.sh"

BACKUP_FILE="${CONFIG_BACKUP_DIR}/original_descriptor.conf"
STRINGS_DIR="${GADGET_DIR}/strings/0x409"

# Ensure config dir exists
ensure_dir "${CONFIG_BACKUP_DIR}"

# ----------------- Pre-Baked Hardware Profiles -----------------

declare -A PROFILE_NAME
declare -A PROFILE_VID
declare -A PROFILE_PID
declare -A PROFILE_BCD_DEV
declare -A PROFILE_BCD_USB
declare -A PROFILE_MANUFACTURER
declare -A PROFILE_PRODUCT
declare -A PROFILE_SERIAL
declare -A PROFILE_DESC

# Profile 1: Apple Magic Keyboard
PROFILE_NAME["apple_magic_kb"]="Apple Magic Keyboard"
PROFILE_VID["apple_magic_kb"]="0x05ac"
PROFILE_PID["apple_magic_kb"]="0x024f"
PROFILE_BCD_DEV["apple_magic_kb"]="0x0110"
PROFILE_BCD_USB["apple_magic_kb"]="0x0200"
PROFILE_MANUFACTURER["apple_magic_kb"]="Apple Inc."
PROFILE_PRODUCT["apple_magic_kb"]="Magic Keyboard"
PROFILE_SERIAL["apple_magic_kb"]="CC2140301K3J3H1AZ"
PROFILE_DESC["apple_magic_kb"]="Apple Inc. Magic Keyboard with Numeric Keypad"

# Profile 2: Logitech Unifying Receiver
PROFILE_NAME["logitech_unifying"]="Logitech Unifying Receiver"
PROFILE_VID["logitech_unifying"]="0x046d"
PROFILE_PID["logitech_unifying"]="0xc52b"
PROFILE_BCD_DEV["logitech_unifying"]="0x2407"
PROFILE_BCD_USB["logitech_unifying"]="0x0200"
PROFILE_MANUFACTURER["logitech_unifying"]="Logitech"
PROFILE_PRODUCT["logitech_unifying"]="USB Receiver"
PROFILE_SERIAL["logitech_unifying"]="000000000000"
PROFILE_DESC["logitech_unifying"]="Logitech 2.4GHz Unifying USB Dongle (KB/Mouse combo)"

# Profile 3: Dell Pro Business Keyboard
PROFILE_NAME["dell_multimedia"]="Dell KB216 Wired Keyboard"
PROFILE_VID["dell_multimedia"]="0x413c"
PROFILE_PID["dell_multimedia"]="0x2113"
PROFILE_BCD_DEV["dell_multimedia"]="0x0108"
PROFILE_BCD_USB["dell_multimedia"]="0x0200"
PROFILE_MANUFACTURER["dell_multimedia"]="Dell Inc."
PROFILE_PRODUCT["dell_multimedia"]="Dell KB216 Wired Keyboard"
PROFILE_SERIAL["dell_multimedia"]="CN0717240190012A"
PROFILE_DESC["dell_multimedia"]="Standard Dell Enterprise Desktop Keyboard"

# Profile 4: SanDisk Cruzer Flash Drive
PROFILE_NAME["sandisk_cruzer"]="SanDisk Cruzer Glide"
PROFILE_VID["sandisk_cruzer"]="0x0781"
PROFILE_PID["sandisk_cruzer"]="0x5575"
PROFILE_BCD_DEV["sandisk_cruzer"]="0x0100"
PROFILE_BCD_USB["sandisk_cruzer"]="0x0200"
PROFILE_MANUFACTURER["sandisk_cruzer"]="SanDisk"
PROFILE_PRODUCT["sandisk_cruzer"]="Cruzer Glide"
PROFILE_SERIAL["sandisk_cruzer"]="4C530001230425112345"
PROFILE_DESC["sandisk_cruzer"]="SanDisk USB 2.0/3.0 High Capacity Flash Drive"

# Profile 5: Microsoft Optical Mouse
PROFILE_NAME["microsoft_mouse"]="Microsoft Basic Optical Mouse"
PROFILE_VID["microsoft_mouse"]="0x045e"
PROFILE_PID["microsoft_mouse"]="0x00cb"
PROFILE_BCD_DEV["microsoft_mouse"]="0x0100"
PROFILE_BCD_USB["microsoft_mouse"]="0x0200"
PROFILE_MANUFACTURER["microsoft_mouse"]="Microsoft"
PROFILE_PRODUCT["microsoft_mouse"]="Microsoft Basic Optical Mouse v2.0"
PROFILE_SERIAL["microsoft_mouse"]="MSFT0001928471"
PROFILE_DESC["microsoft_mouse"]="Microsoft Standard Office Optical Mouse"

# Profile 6: Corsair K70 RGB Gaming Keyboard
PROFILE_NAME["corsair_k70"]="Corsair K70 RGB Gaming Keyboard"
PROFILE_VID["corsair_k70"]="0x1b1c"
PROFILE_PID["corsair_k70"]="0x1b13"
PROFILE_BCD_DEV["corsair_k70"]="0x0205"
PROFILE_BCD_USB["corsair_k70"]="0x0200"
PROFILE_MANUFACTURER["corsair_k70"]="Corsair"
PROFILE_PRODUCT["corsair_k70"]="Corsair K70 RGB Gaming Keyboard"
PROFILE_SERIAL["corsair_k70"]="1B1C0003482109"
PROFILE_DESC["corsair_k70"]="Corsair Mechanical Gaming Keyboard"

# Profile 7: Kingston DataTraveler Flash Drive
PROFILE_NAME["kingston_datatraveler"]="Kingston DataTraveler 3.0"
PROFILE_VID["kingston_datatraveler"]="0x0951"
PROFILE_PID["kingston_datatraveler"]="0x1666"
PROFILE_BCD_DEV["kingston_datatraveler"]="0x0100"
PROFILE_BCD_USB["kingston_datatraveler"]="0x0200"
PROFILE_MANUFACTURER["kingston_datatraveler"]="Kingston"
PROFILE_PRODUCT["kingston_datatraveler"]="DataTraveler 3.0"
PROFILE_SERIAL["kingston_datatraveler"]="0014D11855B6FD10C00000B2"
PROFILE_DESC["kingston_datatraveler"]="Kingston USB 3.0 Flash Storage Drive"

# ----------------- Core Functions -----------------

backup_original_descriptor() {
    if [[ -f "${BACKUP_FILE}" ]]; then
        return 0
    fi

    log_info "Creating initial backup of stock USB descriptors..."
    local vid pid bcd_dev bcd_usb man prod serial
    vid=$(sudo cat "${GADGET_DIR}/idVendor" 2>/dev/null || echo "0x18d1")
    pid=$(sudo cat "${GADGET_DIR}/idProduct" 2>/dev/null || echo "0x4ee1")
    bcd_dev=$(sudo cat "${GADGET_DIR}/bcdDevice" 2>/dev/null || echo "0x0440")
    bcd_usb=$(sudo cat "${GADGET_DIR}/bcdUSB" 2>/dev/null || echo "0x0200")
    man=$(sudo cat "${STRINGS_DIR}/manufacturer" 2>/dev/null || echo "Android")
    prod=$(sudo cat "${STRINGS_DIR}/product" 2>/dev/null || echo "Android")
    serial=$(sudo cat "${STRINGS_DIR}/serialnumber" 2>/dev/null || echo "0123456789ABCDEF")

    cat << BKP_EOF | sudo tee "${BACKUP_FILE}" >/dev/null
ORIG_VID="${vid}"
ORIG_PID="${pid}"
ORIG_BCD_DEV="${bcd_dev}"
ORIG_BCD_USB="${bcd_usb}"
ORIG_MANUFACTURER="${man}"
ORIG_PRODUCT="${prod}"
ORIG_SERIAL="${serial}"
BKP_EOF

    log_success "Original descriptors saved to ${BACKUP_FILE}"
}

read_current_descriptor() {
    CUR_VID=$(sudo cat "${GADGET_DIR}/idVendor" 2>/dev/null || echo "unknown")
    CUR_PID=$(sudo cat "${GADGET_DIR}/idProduct" 2>/dev/null || echo "unknown")
    CUR_BCD_DEV=$(sudo cat "${GADGET_DIR}/bcdDevice" 2>/dev/null || echo "unknown")
    CUR_BCD_USB=$(sudo cat "${GADGET_DIR}/bcdUSB" 2>/dev/null || echo "unknown")
    CUR_MAN=$(sudo cat "${STRINGS_DIR}/manufacturer" 2>/dev/null || echo "unknown")
    CUR_PROD=$(sudo cat "${STRINGS_DIR}/product" 2>/dev/null || echo "unknown")
    CUR_SERIAL=$(sudo cat "${STRINGS_DIR}/serialnumber" 2>/dev/null || echo "unknown")
}

apply_descriptor() {
    local vid="$1"
    local pid="$2"
    local man="$3"
    local prod="$4"
    local serial="$5"
    local bcd_dev="${6:-0x0100}"
    local bcd_usb="${7:-0x0200}"

    backup_original_descriptor

    local was_bound=0
    if is_gadget_bound; then
        was_bound=1
        unbind_udc
    fi

    log_info "Writing spoofed USB descriptors..."
    sudo sh -c "echo '${vid}' > '${GADGET_DIR}/idVendor'"
    sudo sh -c "echo '${pid}' > '${GADGET_DIR}/idProduct'"
    sudo sh -c "echo '${bcd_dev}' > '${GADGET_DIR}/bcdDevice'" 2>/dev/null || true
    sudo sh -c "echo '${bcd_usb}' > '${GADGET_DIR}/bcdUSB'" 2>/dev/null || true

    # Write localized strings
    sudo sh -c "echo '${man}' > '${STRINGS_DIR}/manufacturer'" 2>/dev/null || true
    sudo sh -c "echo '${prod}' > '${STRINGS_DIR}/product'" 2>/dev/null || true
    sudo sh -c "echo '${serial}' > '${STRINGS_DIR}/serialnumber'" 2>/dev/null || true

    if [[ $was_bound -eq 1 ]]; then
        bind_udc
    fi

    log_success "USB Chameleon applied: ${man} - ${prod} (${vid}:${pid})"
}

apply_profile() {
    local prof_key="$1"
    if [[ -z "${PROFILE_NAME[$prof_key]}" ]]; then
        log_error "Unknown profile: '$prof_key'"
        echo "Run '$0 list' to view available profiles."
        return 1
    fi

    print_header "Applying USB Profile: ${PROFILE_NAME[$prof_key]}"
    apply_descriptor \
        "${PROFILE_VID[$prof_key]}" \
        "${PROFILE_PID[$prof_key]}" \
        "${PROFILE_MANUFACTURER[$prof_key]}" \
        "${PROFILE_PRODUCT[$prof_key]}" \
        "${PROFILE_SERIAL[$prof_key]}" \
        "${PROFILE_BCD_DEV[$prof_key]}" \
        "${PROFILE_BCD_USB[$prof_key]}"
}

restore_original() {
    print_header "Restoring Stock USB Descriptors"
    if [[ ! -f "${BACKUP_FILE}" ]]; then
        log_warn "No backup file found at ${BACKUP_FILE}. Using standard Android defaults..."
        apply_descriptor "0x18d1" "0x4ee1" "Google" "Android" "0123456789ABCDEF" "0x0440" "0x0200"
        return 0
    fi

    # Source backup
    source "${BACKUP_FILE}"
    apply_descriptor \
        "${ORIG_VID}" \
        "${ORIG_PID}" \
        "${ORIG_MANUFACTURER}" \
        "${ORIG_PRODUCT}" \
        "${ORIG_SERIAL}" \
        "${ORIG_BCD_DEV}" \
        "${ORIG_BCD_USB}"

    log_success "Restored stock USB hardware identity."
}

list_profiles() {
    print_header "Available Pre-Baked Hardware Profiles"
    printf "%-22s | %-9s | %-16s | %s\n" "Profile ID" "VID:PID" "Vendor" "Device Description"
    printf -- "-----------------------+-----------+------------------+--------------------------------------\n"
    for key in "apple_magic_kb" "logitech_unifying" "dell_multimedia" "sandisk_cruzer" "microsoft_mouse" "corsair_k70" "kingston_datatraveler"; do
        printf "%-22s | %-9s | %-16s | %s\n" \
            "${key}" \
            "${PROFILE_VID[$key]#0x}:${PROFILE_PID[$key]#0x}" \
            "${PROFILE_MANUFACTURER[$key]}" \
            "${PROFILE_DESC[$key]}"
    done
    echo
}

status() {
    read_current_descriptor
    local udc
    udc=$(get_udc)

    print_header "USB Chameleon Descriptor Status"
    echo -e "Active UDC:          ${udc:-<unbound>}"
    echo -e "Vendor ID (VID):     ${COLOR_CYAN}${CUR_VID}${COLOR_RESET}"
    echo -e "Product ID (PID):    ${COLOR_CYAN}${CUR_PID}${COLOR_RESET}"
    echo -e "Manufacturer:        ${COLOR_GREEN}${CUR_MAN}${COLOR_RESET}"
    echo -e "Product String:      ${COLOR_GREEN}${CUR_PROD}${COLOR_RESET}"
    echo -e "Serial Number:       ${CUR_SERIAL}"
    echo -e "Device Revision:     ${CUR_BCD_DEV}"
    echo -e "USB Specification:   ${CUR_BCD_USB}"
    echo
    if [[ -f "${BACKUP_FILE}" ]]; then
        source "${BACKUP_FILE}"
        echo -e "${COLOR_DIM}Stock Backup: ${ORIG_MANUFACTURER} ${ORIG_PRODUCT} (${ORIG_VID}:${ORIG_PID})${COLOR_RESET}"
    fi
    echo
}

custom_profile_wizard() {
    print_header "Custom USB Descriptor Spoofing"
    read -rp "Vendor ID [hex, e.g. 0x05ac]: " vid
    read -rp "Product ID [hex, e.g. 0x024f]: " pid
    read -rp "Manufacturer String [e.g. Apple Inc.]: " man
    read -rp "Product String [e.g. Magic Keyboard]: " prod
    read -rp "Serial Number [optional]: " serial
    serial="${serial:-CUSTOM$(date +%s)}"

    [[ -z "$vid" || -z "$pid" || -z "$man" || -z "$prod" ]] && {
        log_error "VID, PID, Manufacturer, and Product string are required."
        return 1
    }

    [[ "$vid" != 0x* ]] && vid="0x${vid}"
    [[ "$pid" != 0x* ]] && pid="0x${pid}"

    apply_descriptor "$vid" "$pid" "$man" "$prod" "$serial"
}

# ----------------- Interactive Menu -----------------

menu() {
    backup_original_descriptor
    while true; do
        print_header "USB Chameleon (Descriptor & Identity Cloner)"
        status
        echo " 1) Apply Pre-Baked Hardware Profile"
        echo " 2) Custom VID / PID / String Spoof"
        echo " 3) Restore Stock Hardware Identity"
        echo " 4) List All Profiles"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1)
                list_profiles
                read -rp "Enter Profile ID to apply: " prof
                if [[ -n "$prof" ]]; then
                    apply_profile "$prof"
                fi
                press_enter ;;
            2)
                custom_profile_wizard
                press_enter ;;
            3)
                restore_original
                press_enter ;;
            4)
                list_profiles
                press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

# CLI Argument Router
case "${1:-}" in
    apply)   apply_profile "${2:-}" ;;
    custom)  apply_descriptor "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" ;;
    restore) restore_original ;;
    list)    list_profiles ;;
    status)  status ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {apply <profile>|custom <vid> <pid> <man> <prod> [serial]|restore|list|status|menu}" ;;
esac
