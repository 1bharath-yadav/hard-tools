#!/usr/bin/env bash
#
# hard-tools: launcher.sh
# Master Dashboard & TUI Launcher for USB Arsenal & Hardware Tooling
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

USB_DIR="${SCRIPT_DIR}/usb_gadget"
NET_DIR="${SCRIPT_DIR}/network"
OP_DIR="${SCRIPT_DIR}/operator"
BT_DIR="${SCRIPT_DIR}/bluetooth"

MASS_STORAGE_BIN="${USB_DIR}/mass_storage_manager.sh"
USB_GADGET_BIN="${USB_DIR}/hid.sh"
RNDIS_BIN="${USB_DIR}/rndis.sh"
BADUSB_BIN="${USB_DIR}/badusb.sh"
UVC_BIN="${USB_DIR}/uvc.sh"
ADB_BIN="${USB_DIR}/adb.sh"
MTP_BIN="${USB_DIR}/mtp_ptp.sh"
NETFILTER_BIN="${NET_DIR}/netfilter.sh"
BT_BIN="${BT_DIR}/bt_arsenal.sh"
RECON_BIN="${OP_DIR}/recon.sh"
SESSION_BIN="${OP_DIR}/session.sh"

get_module_status() {
    local mod="$1"
    case "$mod" in
        mass_storage)
            if is_function_linked "mass_storage.0"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        adb)
            if is_function_linked "ffs.adb" || is_function_linked "function0"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        hid)
            if is_function_linked "hid.keyboard" || is_function_linked "hid.touchpad"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        rndis)
            if is_function_linked "rndis.rndis"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        badusb)
            if [[ -f "/tmp/badusb_portal.pid" ]] && kill -0 "$(cat /tmp/badusb_portal.pid 2>/dev/null || echo 0)" 2>/dev/null; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        uvc)
            if is_function_linked "uvc.0"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        mtp)
            if is_function_linked "ffs.mtp" || is_function_linked "ffs.ptp"; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
    esac
}

show_banner() {
    clear 2>/dev/null || true
    local udc
    udc=$(get_udc)
    local udc_display="${COLOR_GREEN}${udc}${COLOR_RESET}"
    [[ -z "$udc" ]] && udc_display="${COLOR_YELLOW}<UNBOUND>${COLOR_RESET}"

    printf "${COLOR_CYAN}"
    cat << 'BANNER_EOF'
   __               __     __             __    
  / /  ___ ________/ /____/ /____  ___   / /____
 / _ \/ _ `/ __/ _  /___/ __/ _ \/ _ \ / (_-<_-<
/_//_/\_,_/_/  \_,_/    \__/\___/\___//_/___/___/
BANNER_EOF
    printf "${COLOR_RESET}"
    printf "${COLOR_BOLD}  DroidSpaces USB Arsenal & Multi-Gadget Suite${COLOR_RESET}\n"
    printf "  UDC Controller: %s | Host Connection: %s\n" "$(detect_udc)" "${udc_display}"
    printf "${COLOR_CYAN}====================================================${COLOR_RESET}\n"
}

show_main_menu() {
    show_banner
    echo -e "  ${COLOR_BOLD}USB Gadget Modules (usb_gadget/):${COLOR_RESET}"
    echo -e "   1) Mass Storage Manager    $(get_module_status mass_storage)"
    echo -e "   2) ADB Gadget Switch       $(get_module_status adb)"
    echo -e "   3) USB HID Controller      $(get_module_status hid)  [KB/MOUSE/DUCKY]"
    echo -e "   4) RNDIS USB Ethernet      $(get_module_status rndis)"
    echo -e "   5) BadUSB (Rogue Gateway)  $(get_module_status badusb)"
    echo -e "   6) UVC USB Webcam          $(get_module_status uvc)"
    echo -e "   7) MTP / PTP Media Mode    $(get_module_status mtp)"
    echo
    echo -e "  ${COLOR_BOLD}Network & Operator Tools:${COLOR_RESET}"
    echo -e "   8) Bluetooth Attack Suite  ${COLOR_DIM}[ANDROID BT / BLUEZ]${COLOR_RESET}"
    echo -e "   9) Netfilter & Sniffer     ${COLOR_DIM}[IPTABLES/PCAP]${COLOR_RESET}"
    echo -e "  10) System & Bus Recon      ${COLOR_DIM}[operator/recon.sh]${COLOR_RESET}"
    echo -e "  11) Session Logger          ${COLOR_DIM}[operator/session.sh]${COLOR_RESET}"
    echo
    echo -e "  ${COLOR_BOLD}Quick Utilities:${COLOR_RESET}"
    echo -e "  12) Emergency Unbind All USB Gadgets"
    echo -e "  13) View ConfigFS Active Links"
    echo -e "   0) Exit"
    echo
}

emergency_unbind() {
    print_header "Emergency Unbind & Release"
    unbind_udc
    log_success "Gadget disconnected from host."
    press_enter
}

show_active_configfs() {
    print_header "Active ConfigFS Symlinks (/config/usb_gadget/g1/configs/b.1)"
    sudo ls -la "${CONFIG_DIR}"
    echo
    press_enter
}

main() {
    while true; do
        show_main_menu
        read -rp "Select option [0-13]: " opt
        case "$opt" in
            1)
                if [[ -x "${MASS_STORAGE_BIN}" ]]; then
                    "${MASS_STORAGE_BIN}"
                else
                    bash "${MASS_STORAGE_BIN}"
                fi ;;
            2)  bash "${ADB_BIN}" ;;
            3)  sudo "${USB_GADGET_BIN}" tui ;;
            4)  bash "${RNDIS_BIN}" ;;
            5)  bash "${BADUSB_BIN}" ;;
            6)  bash "${UVC_BIN}" ;;
            7)  bash "${MTP_BIN}" ;;
            8)  bash "${BT_BIN}" ;;
            9)  bash "${NETFILTER_BIN}" ;;
            10) bash "${RECON_BIN}" ;;
            11) bash "${SESSION_BIN}" ;;
            12) emergency_unbind ;;
            13) show_active_configfs ;;
            0|q|Q|exit)
                c_cyan "Exiting hard-tools USB Arsenal. Happy Hacking!"
                exit 0 ;;
            *)
                c_red "Invalid selection."
                sleep 1 ;;
        esac
    done
}

main
