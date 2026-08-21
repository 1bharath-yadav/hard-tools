#!/data/data/com.termux/files/usr/bin/bash
#
# hard-tools: network/net_recon.sh
# Passive Layer-2/3 Network Reconnaissance, ARP/DHCP/DNS Telemetry & Socket Attribution
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh" 2>/dev/null || {
    COLOR_RESET="\033[0m"; COLOR_BOLD="\033[1m"; COLOR_RED="\033[31m"; COLOR_GREEN="\033[32m"; COLOR_YELLOW="\033[33m"; COLOR_CYAN="\033[36m"
    log_info() { echo -e "${COLOR_CYAN}[*]${COLOR_RESET} $*"; }
    log_success() { echo -e "${COLOR_GREEN}[+]${COLOR_RESET} $*"; }
    log_warn() { echo -e "${COLOR_YELLOW}[!]${COLOR_RESET} $*"; }
    log_error() { echo -e "${COLOR_RED}[-]${COLOR_RESET} $*"; }
    print_header() { echo -e "\n${COLOR_BOLD}=== $* ===${COLOR_RESET}\n"; }
}

detect_active_iface() {
    for iface in wlan0 usb0 rndis0 ap0 p2p0 eth0; do
        if ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
            echo "$iface"
            return 0
        fi
    done
    echo "any"
}

ensure_tcpdump() {
    if ! command -v tcpdump >/dev/null 2>&1 && ! su -c "command -v tcpdump" >/dev/null 2>&1; then
        log_error "tcpdump is required for passive packet capture."
        log_info "Install with: pkg install tcpdump"
        return 1
    fi
    return 0
}

recon_arp() {
    local iface="${1:-$(detect_active_iface)}"
    print_header "Passive ARP Network Discovery (Interface: $iface)"
    ensure_tcpdump || return 1
    log_info "Listening for passive ARP broadcast announcements (Press Ctrl+C to stop)..."
    echo

    su -c "tcpdump -i '$iface' -l -n -e arp 2>/dev/null" | while read -r line; do
        local ts mac_src mac_dst ip_src ip_dst
        ts=$(echo "$line" | awk '{print $1}')
        mac_src=$(echo "$line" | awk '{print $2}')
        if echo "$line" | grep -q "Request who-has"; then
            ip_dst=$(echo "$line" | sed -n 's/.*who-has \([^ ]*\) tell.*/\1/p')
            ip_src=$(echo "$line" | sed -n 's/.*tell \([^,]*\).*/\1/p')
            echo -e "${COLOR_CYAN}[ARP REQ]${COLOR_RESET} ${COLOR_BOLD}${ip_src}${COLOR_RESET} (${mac_src}) -> Looking for ${COLOR_YELLOW}${ip_dst}${COLOR_RESET}"
        elif echo "$line" | grep -q "Reply"; then
            ip_src=$(echo "$line" | sed -n 's/.*Reply \([^ ]*\) is-at.*/\1/p')
            echo -e "${COLOR_GREEN}[ARP RPL]${COLOR_RESET} ${COLOR_BOLD}${ip_src}${COLOR_RESET} is at ${COLOR_GREEN}${mac_src}${COLOR_RESET}"
        fi
    done
}

recon_dhcp() {
    local iface="${1:-$(detect_active_iface)}"
    print_header "Passive DHCP Snooper & Host Discovery (Interface: $iface)"
    ensure_tcpdump || return 1
    log_info "Listening for DHCP Discover/Request/ACK broadcasts (Press Ctrl+C to stop)..."
    echo

    su -c "tcpdump -i '$iface' -l -n -vvv -s 1500 'port 67 or port 68' 2>/dev/null" | while read -r line; do
        if echo "$line" | grep -q "Hostname Option"; then
            local hname
            hname=$(echo "$line" | sed -n 's/.*Hostname Option [0-9]*, length [0-9]*: "\(.*\)".*/\1/p')
            echo -e "${COLOR_GREEN}[DHCP HOSTNAME]${COLOR_RESET} Client Hostname: ${COLOR_BOLD}${hname}${COLOR_RESET}"
        elif echo "$line" | grep -q "Vendor-Class Option"; then
            local vclass
            vclass=$(echo "$line" | sed -n 's/.*Vendor-Class Option [0-9]*, length [0-9]*: "\(.*\)".*/\1/p')
            echo -e "${COLOR_CYAN}[DHCP VENDOR]${COLOR_RESET} Device Vendor Class: ${COLOR_YELLOW}${vclass}${COLOR_RESET}"
        elif echo "$line" | grep -q "Requested-IP Option"; then
            local reqip
            reqip=$(echo "$line" | sed -n 's/.*Requested-IP Option [0-9]*, length [0-9]*: \([0-9\.]*\).*/\1/p')
            echo -e "${COLOR_YELLOW}[DHCP REQ-IP]${COLOR_RESET} Requested IP: ${COLOR_BOLD}${reqip}${COLOR_RESET}"
        fi
    done
}

recon_dns() {
    local iface="${1:-$(detect_active_iface)}"
    print_header "Passive DNS Query & Resolution Monitor (Interface: $iface)"
    ensure_tcpdump || return 1
    log_info "Monitoring real-time DNS queries and IP lookups (Press Ctrl+C to stop)..."
    echo

    su -c "tcpdump -i '$iface' -l -n -s 512 'udp port 53 or tcp port 53' 2>/dev/null" | while read -r line; do
        local query
        if echo "$line" | grep -q " A? "; then
            query=$(echo "$line" | sed -n 's/.* A? \([^ ]*\).*/\1/p')
            local src
            src=$(echo "$line" | awk '{print $3}' | cut -d'.' -f1-4)
            echo -e "${COLOR_CYAN}[DNS QUERY]${COLOR_RESET} ${COLOR_BOLD}${src}${COLOR_RESET} -> ${COLOR_YELLOW}${query}${COLOR_RESET}"
        elif echo "$line" | grep -q " A "; then
            local ans
            ans=$(echo "$line" | sed -n 's/.* A \([0-9\.]*\).*/\1/p')
            [[ -n "$ans" ]] && echo -e "${COLOR_GREEN}[DNS ANSWER]${COLOR_RESET} Resolved: ${COLOR_GREEN}${ans}${COLOR_RESET}"
        fi
    done
}

recon_sockets() {
    print_header "Active Socket Connections & Application UID Attribution"
    
    echo -e "  ${COLOR_BOLD}Proto  Local Address          Foreign Address        PID/Program (UID)${COLOR_RESET}"
    echo "  --------------------------------------------------------------------------------"
    su -c "ss -tunap" 2>/dev/null | awk 'NR>1 {printf "  %-5s  %-21s  %-21s  %s\n", $1, $5, $6, $7}' || su -c "netstat -tunp" 2>/dev/null
    echo
}

menu() {
    while true; do
        clear 2>/dev/null || true
        local def_iface
        def_iface=$(detect_active_iface)
        print_header "Passive Network Reconnaissance & Telemetry"
        echo -e "  Active Interface Detected: ${COLOR_BOLD}${def_iface}${COLOR_RESET}\n"
        echo "   1) Passive ARP Discovery (Live Host & MAC Mapping)"
        echo "   2) Passive DHCP Snooper (Hostnames & Vendor Classes)"
        echo "   3) Real-Time DNS Query & Domain Monitor"
        echo "   4) Active Sockets & Process/UID Attribution (ss / netstat)"
        echo
        echo "   0) Back to Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1)
                read -rp "Enter Interface [$def_iface]: " ifc
                recon_arp "${ifc:-$def_iface}"
                read -rp "Press Enter to continue..." ;;
            2)
                read -rp "Enter Interface [$def_iface]: " ifc
                recon_dhcp "${ifc:-$def_iface}"
                read -rp "Press Enter to continue..." ;;
            3)
                read -rp "Enter Interface [$def_iface]: " ifc
                recon_dns "${ifc:-$def_iface}"
                read -rp "Press Enter to continue..." ;;
            4) recon_sockets; read -rp "Press Enter to continue..." ;;
            0) break ;;
            *) sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    arp)    recon_arp "${2:-}" ;;
    dhcp)   recon_dhcp "${2:-}" ;;
    dns)    recon_dns "${2:-}" ;;
    sockets|conns) recon_sockets ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {arp [iface]|dhcp [iface]|dns [iface]|sockets|menu}" ;;
esac
