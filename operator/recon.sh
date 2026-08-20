#!/usr/bin/env bash
#
# hard-tools: scripts/recon.sh
# Terminal-native local system, USB bus, and network reconnaissance tool
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

recon_system() {
    print_header "Host & Kernel Reconnaissance"
    echo -e "${COLOR_BOLD}Kernel Release:${COLOR_RESET} $(uname -r)"
    echo -e "${COLOR_BOLD}Architecture:${COLOR_RESET}   $(uname -m)"
    echo -e "${COLOR_BOLD}Uptime:${COLOR_RESET}         $(uptime -p 2>/dev/null || uptime)"
    echo -e "${COLOR_BOLD}Memory:${COLOR_RESET}         $(free -h 2>/dev/null | grep Mem | awk '{print $3 " used / " $2 " total"}')"
    echo
}

recon_usb() {
    print_header "USB Gadget & Host Controller Recon"
    echo -e "${COLOR_BOLD}Active UDC Controller:${COLOR_RESET} $(get_udc)"
    echo -e "${COLOR_BOLD}Hardware Controllers:${COLOR_RESET}"
    ls -la /sys/class/udc/ 2>/dev/null || echo "No UDC controllers found"
    echo
    echo -e "${COLOR_BOLD}ConfigFS Functions Registered:${COLOR_RESET}"
    for f in /config/usb_gadget/g1/functions/*; do
        [[ -d "$f" ]] && echo "  * $(basename "$f")"
    done
    echo
    echo -e "${COLOR_BOLD}Active Linked Functions (configs/b.1):${COLOR_RESET}"
    for link in /config/usb_gadget/g1/configs/b.1/*; do
        [[ -L "$link" ]] && echo "  * $(basename "$link") -> $(readlink "$link")"
    done
    echo
}

recon_network() {
    print_header "Network Interfaces & Routing Recon"
    echo -e "${COLOR_BOLD}Active IP Interfaces:${COLOR_RESET}"
    ip -br addr show 2>/dev/null || ifconfig 2>/dev/null
    echo
    echo -e "${COLOR_BOLD}Kernel Routing Table:${COLOR_RESET}"
    ip route show 2>/dev/null || route -n 2>/dev/null
    echo
    echo -e "${COLOR_BOLD}Active ARP / Neighbor Table:${COLOR_RESET}"
    ip neigh show 2>/dev/null || arp -an 2>/dev/null
    echo
}

recon_services() {
    print_header "Active Listening Sockets & Ports"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln
    fi
    echo
}

run_full_recon() {
    recon_system
    recon_usb
    recon_network
    recon_services
}

menu() {
    while true; do
        print_header "System & Network Reconnaissance"
        echo " 1) Full Reconnaissance Report"
        echo " 2) Host & Kernel Info"
        echo " 3) USB Gadget & UDC Subsystem"
        echo " 4) Network Interfaces & Routes"
        echo " 5) Listening Sockets & Services"
        echo " 0) Back"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) run_full_recon; press_enter ;;
            2) recon_system; press_enter ;;
            3) recon_usb; press_enter ;;
            4) recon_network; press_enter ;;
            5) recon_services; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    system)  recon_system ;;
    usb)     recon_usb ;;
    net)     recon_network ;;
    ports)   recon_services ;;
    full)    run_full_recon ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {system|usb|net|ports|full|menu}" ;;
esac
