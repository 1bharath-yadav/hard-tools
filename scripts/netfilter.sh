#!/usr/bin/env bash
#
# hard-tools: scripts/netfilter.sh
# Netfilter Traffic Redirection, Port Forwarding & Packet Sniffer
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

PCAP_DIR="${STORAGE_DIR}"
[[ ! -d "${PCAP_DIR}" ]] && PCAP_DIR="$(pwd)"
DEFAULT_PCAP="${PCAP_DIR}/capture.pcap"

detect_default_iface() {
    for iface in rndis0 usb0 wlan0 eth0; do
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "$iface"
            return 0
        fi
    done
    echo "any"
}

sniff_dns() {
    print_header "DNS Query Monitor (Port 53)"
    local iface
    read -rp "Interface to sniff on [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"

    log_info "Capturing DNS queries on ${iface}... (Press Ctrl+C to stop)"
    sudo tcpdump -i "${iface}" -n -l -q "udp port 53"
}

sniff_http() {
    print_header "HTTP Plaintext Traffic Sniffer"
    local iface
    read -rp "Interface to sniff on [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"

    log_info "Capturing HTTP requests/responses on ${iface}... (Press Ctrl+C to stop)"
    sudo tcpdump -i "${iface}" -n -A -s 0 "tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12:1] & 0xf0)>>2)) != 0)"
}

capture_pcap() {
    print_header "Full Packet Capture (PCAP)"
    local iface pfile
    read -rp "Interface to capture [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"
    read -rp "PCAP output file [${DEFAULT_PCAP}]: " pfile
    pfile="${pfile:-$DEFAULT_PCAP}"

    log_info "Writing packet capture to: ${pfile} (Press Ctrl+C to stop)..."
    sudo tcpdump -i "${iface}" -w "${pfile}"
    log_success "Saved capture to ${pfile} ($(du -h "${pfile}" 2>/dev/null | cut -f1))"
}

redirect_port() {
    print_header "Iptables Port Redirection / Transparent Proxy"
    read -rp "Incoming port to intercept (e.g. 80): " in_port
    read -rp "Target local destination port (e.g. 8080): " dest_port
    [[ -z "$in_port" || -z "$dest_port" ]] && return 1

    log_info "Adding iptables PREROUTING rule: Redirect port $in_port -> $dest_port..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport "$in_port" -j REDIRECT --to-ports "$dest_port"
    log_success "Port redirection active."
}

flush_nat_rules() {
    print_header "Flush NAT / Redirection Rules"
    sudo iptables -t nat -F PREROUTING 2>/dev/null || true
    log_success "Flushed iptables PREROUTING NAT table."
}

status() {
    print_header "Netfilter & Iptables Status"
    echo "--- Active NAT PREROUTING Rules ---"
    sudo iptables -t nat -L PREROUTING -v -n 2>/dev/null || echo "N/A"
    echo
    echo "--- Active Forwarding Rules ---"
    sudo iptables -L FORWARD -v -n 2>/dev/null || echo "N/A"
    echo
}

menu() {
    while true; do
        print_header "Netfilter & Packet Capture Arsenal"
        status
        echo " 1) Live DNS Query Monitor (Port 53)"
        echo " 2) Live HTTP Plaintext Sniffer (Port 80)"
        echo " 3) Full Packet Capture to PCAP File"
        echo " 4) Redirect Port (Transparent proxy / MITM)"
        echo " 5) Flush PREROUTING Redirection Rules"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) sniff_dns; press_enter ;;
            2) sniff_http; press_enter ;;
            3) capture_pcap; press_enter ;;
            4) redirect_port; press_enter ;;
            5) flush_nat_rules; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    dns)     sniff_dns ;;
    http)    sniff_http ;;
    pcap)    capture_pcap ;;
    flush)   flush_nat_rules ;;
    status)  status ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {dns|http|pcap|flush|status|menu}" ;;
esac
