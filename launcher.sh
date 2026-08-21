#!/usr/bin/env bash
#
# hard-tools: launcher.sh
# Master Dashboard & TUI Launcher for USB Arsenal & Hardware Penetration Testing Suite
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
CHAMELEON_BIN="${USB_DIR}/chameleon.sh"
COMPOSITE_BIN="${USB_DIR}/composite.sh"
UVC_BIN="${USB_DIR}/uvc.sh"
ADB_BIN="${USB_DIR}/adb.sh"
MTP_BIN="${USB_DIR}/mtp_ptp.sh"

NETFILTER_BIN="${NET_DIR}/netfilter.sh"
BT_BIN="${BT_DIR}/bt_arsenal.sh"
RECON_BIN="${OP_DIR}/recon.sh"
SESSION_BIN="${OP_DIR}/session.sh"
DUCKY_BIN="${OP_DIR}/ducky.sh"

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
        chameleon)
            local cur_vid
            cur_vid=$(sudo cat "${GADGET_DIR}/idVendor" 2>/dev/null || echo "0x18d1")
            if [[ "$cur_vid" != "0x18d1" ]]; then
                printf "${COLOR_MAGENTA}[SPOOFED]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[STOCK]${COLOR_RESET}"
            fi ;;
        composite)
            if [[ -f "/tmp/composite_profile.state" ]]; then
                printf "${COLOR_GREEN}[%s]${COLOR_RESET}" "$(cat /tmp/composite_profile.state | tr '[:lower:]' '[:upper:]')"
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
        pcap_streamer)
            if [[ -f "/tmp/pcap_streamer.pid" ]] && kill -0 "$(cat /tmp/pcap_streamer.pid 2>/dev/null || echo 0)" 2>/dev/null; then
                printf "${COLOR_GREEN}[STREAMING]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        bt_hid)
            if su -c "dumpsys activity services com.example.hidtest 2>/dev/null | grep -q 'HidService'" 2>/dev/null; then
                printf "${COLOR_GREEN}[ACTIVE]${COLOR_RESET}"
            else
                printf "${COLOR_DIM}[OFF]${COLOR_RESET}"
            fi ;;
        bt_snoop)
            local snoop_mode
            snoop_mode=$(su -c "getprop persist.bluetooth.btsnoopdefaultmode" 2>/dev/null | tr -d '\r\n')
            if [[ "$snoop_mode" == "full" ]]; then
                printf "${COLOR_GREEN}[LOGGING]${COLOR_RESET}"
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

    local cur_prod
    cur_prod=$(sudo cat "${GADGET_DIR}/strings/0x409/product" 2>/dev/null || echo "Unknown")

    printf "${COLOR_CYAN}"
    cat << 'BANNER_EOF'
   __               __     __             __    
  / /  ___ ________/ /____/ /____  ___   / /____
 / _ \/ _ `/ __/ _  /___/ __/ _ \/ _ \ / (_-<_-<
/_//_/\_,_/_/  \_,_/    \__/\___/\___//_/___/___/
BANNER_EOF
    printf "${COLOR_RESET}"
    printf "${COLOR_BOLD}  DroidSpaces USB Arsenal & Hardware Weaponization Suite${COLOR_RESET}\n"
    printf "  Hardware UDC: %s | Host: %s | Device: %s\n" "$(detect_udc)" "${udc_display}" "${cur_prod}"
    printf "${COLOR_CYAN}================================================================${COLOR_RESET}\n"
}

show_main_menu() {
    show_banner
    echo -e "  ${COLOR_BOLD}USB Gadget Weaponization (usb_gadget/):${COLOR_RESET}"
    echo -e "   1) Mass Storage Manager    $(get_module_status mass_storage)  [CD-ROM ISO / FLASH]"
    echo -e "   2) USB HID Controller      $(get_module_status hid)  [KEYBOARD / TOUCHPAD / JIGGLER]"
    echo -e "   3) BadUSB (Rogue Gateway)  $(get_module_status badusb)  [AGGRESSIVE DHCP + CAPTIVE PORTAL]"
    echo -e "   4) USB Chameleon (VID/PID) $(get_module_status chameleon)  [HARDWARE IDENTITY SPOOFER]"
    echo -e "   5) Composite Attack Suite  $(get_module_status composite)  [MULTI-FUNCTION ATTACK STACKING]"
    echo -e "   6) RNDIS USB Ethernet      $(get_module_status rndis)  [NAT ROUTER & DHCP GATEWAY]"
    echo -e "   7) ADB Gadget Switch       $(get_module_status adb)"
    echo -e "   8) UVC USB Webcam          $(get_module_status uvc)"
    echo -e "   9) MTP / PTP Media Mode    $(get_module_status mtp)"
    echo
    echo -e "  ${COLOR_BOLD}Wireless Bluetooth, Packet Capture & Observability:${COLOR_RESET}"
    echo -e "  10) Weaponized Ducky 3.0    ${COLOR_DIM}[MULTI-OS STAGED ARSENAL]${COLOR_RESET}"
    echo -e "  11) Netfilter & Sniffer     $(get_module_status pcap_streamer)  [IPTABLES / WIRESHARK BRIDGE]"
    echo -e "  12) Passive Network Recon   ${COLOR_DIM}[ARP / DHCP / DNS / SOCKET TELEMETRY]${COLOR_RESET}"
    echo -e "  13) Bluetooth HID Device    $(get_module_status bt_hid)  [WIRELESS KEYBOARD / DUCKY INJECTION]"
    echo -e "  14) Bluetooth BTSnoop HCI   $(get_module_status bt_snoop)  [QUALCOMM HAL PCAP STREAMER]"
    echo -e "  15) Bluetooth Arsenal Suite ${COLOR_DIM}[ANDROID BT / BINDER ARSENAL]${COLOR_RESET}"
    echo -e "  16) Kernel Ftrace & Kprobes ${COLOR_DIM}[SYSCALL / BINDER / NET TRACING]${COLOR_RESET}"
    echo -e "  17) System & Bus Recon      ${COLOR_DIM}[operator/recon.sh]${COLOR_RESET}"
    echo -e "  18) Terminal Session Logger ${COLOR_DIM}[operator/session.sh]${COLOR_RESET}"
    echo
    echo -e "  ${COLOR_BOLD}System Operations:${COLOR_RESET}"
    echo -e "  19) Emergency Unbind All USB Gadgets"
    echo -e "  20) View ConfigFS Active Links"
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
        read -rp "Select option [0-20]: " opt
        case "$opt" in
            1)
                if [[ -x "${MASS_STORAGE_BIN}" ]]; then
                    "${MASS_STORAGE_BIN}"
                else
                    bash "${MASS_STORAGE_BIN}"
                fi ;;
            2)  sudo "${USB_GADGET_BIN}" tui ;;
            3)  bash "${BADUSB_BIN}" ;;
            4)  bash "${CHAMELEON_BIN}" ;;
            5)  bash "${COMPOSITE_BIN}" ;;
            6)  bash "${RNDIS_BIN}" ;;
            7)  bash "${ADB_BIN}" ;;
            8)  bash "${UVC_BIN}" ;;
            9)  bash "${MTP_BIN}" ;;
            10) bash "${DUCKY_BIN}" ;;
            11) bash "${NETFILTER_BIN}" ;;
            12) bash "${NET_DIR}/net_recon.sh" ;;
            13) bash "${BT_DIR}/bt-hid" ;;
            14) bash "${BT_DIR}/bt-snoop" ;;
            15) bash "${BT_BIN}" ;;
            16) bash "${OP_DIR}/ktrace.sh" ;;
            17) bash "${RECON_BIN}" ;;
            18) bash "${SESSION_BIN}" ;;
            19) emergency_unbind ;;
            20) show_active_configfs ;;
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
