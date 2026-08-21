#!/usr/bin/env bash
#
# hard-tools: network/netfilter.sh
# Netfilter Traffic Redirection, Port Forwarding, Packet Sniffer & Live PCAP Remote Streamer
# Bridges live host network traffic to remote Wireshark listeners in real time.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

PCAP_DIR="${STORAGE_DIR}"
[[ ! -d "${PCAP_DIR}" ]] && PCAP_DIR="${ROOT_DIR}/images"
ensure_dir "${PCAP_DIR}"
DEFAULT_PCAP="${PCAP_DIR}/capture_$(date +%Y%m%d_%H%M%S).pcap"

PID_STREAMER="/tmp/pcap_streamer.pid"
DEFAULT_STREAM_PORT=9999

detect_default_iface() {
    for iface in rndis0 usb0 wlan0 eth0; do
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "$iface"
            return 0
        fi
    done
    echo "any"
}

get_local_ip() {
    local iface="$1"
    if [[ -n "$iface" && "$iface" != "any" ]]; then
        ip -4 addr show dev "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "127.0.0.1"
    else
        ip route get 1.1.1.1 2>/dev/null | grep -oP '(?<=src\s)\d+(\.\d+){3}' | head -n1 || echo "127.0.0.1"
    fi
}

# ----------------- Live PCAP Remote Streamer -----------------

start_pcap_streamer() {
    local port="${1:-$DEFAULT_STREAM_PORT}"
    local iface="${2:-$(detect_default_iface)}"

    stop_pcap_streamer 2>/dev/null

    print_header "Starting Live PCAP Remote Streamer (Wireshark Bridge)"
    log_info "Interface: ${iface} | Streaming Port: ${port}"

    local streamer_bin="ncat"
    if ! command -v ncat >/dev/null 2>&1; then
        if command -v nc >/dev/null 2>&1; then
            streamer_bin="nc"
        else
            log_error "Neither ncat nor nc is installed!"
            return 1
        fi
    fi

    local dev_ip
    dev_ip=$(get_local_ip "$iface")
    local wlan_ip
    wlan_ip=$(get_local_ip "wlan0")

    # Start tcpdump piped into ncat listening on TCP port
    sudo sh -c "tcpdump -i '${iface}' -U -s 0 -w - not port 22 not port ${port} 2>/tmp/pcap_streamer.err | ${streamer_bin} -l -k -p ${port} >/dev/null 2>&1" &
    local stream_pid=$!
    echo "$stream_pid" | sudo tee "${PID_STREAMER}" >/dev/null

    sleep 0.5
    log_success "PCAP Streamer is running in background (PID ${stream_pid})."

    echo
    echo -e "${COLOR_BOLD}=== Workstation / Remote Operator Connection Commands ===${COLOR_RESET}"
    echo -e "${COLOR_CYAN}1. Linux / macOS (Wireshark Live Pipe):${COLOR_RESET}"
    echo -e "   ncat ${wlan_ip} ${port} | wireshark -k -i -"
    echo -e "   or:"
    echo -e "   wireshark -k -i <(nc ${wlan_ip} ${port})"
    echo
    echo -e "${COLOR_CYAN}2. Windows (PowerShell / Command Prompt):${COLOR_RESET}"
    echo -e "   ncat.exe ${wlan_ip} ${port} | Wireshark.exe -k -i -"
    echo
    echo -e "${COLOR_CYAN}3. Direct PCAP File Dumping on Remote Machine:${COLOR_RESET}"
    echo -e "   ncat ${wlan_ip} ${port} > live_intercept.pcap"
    echo
}

stop_pcap_streamer() {
    print_header "Stopping PCAP Remote Streamer"
    if [[ -f "${PID_STREAMER}" ]]; then
        local pid
        pid=$(sudo cat "${PID_STREAMER}" 2>/dev/null || true)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            sudo kill "${pid}" 2>/dev/null || true
        fi
        sudo rm -f "${PID_STREAMER}" 2>/dev/null || true
    fi
    sudo pkill -f "tcpdump.*pcap_streamer" 2>/dev/null || true
    sudo pkill -f "ncat.*-p 9999" 2>/dev/null || true
    log_success "PCAP Streamer STOPPED."
}

streamer_status() {
    if [[ -f "${PID_STREAMER}" ]] && kill -0 "$(sudo cat "${PID_STREAMER}" 2>/dev/null || echo 0)" 2>/dev/null; then
        echo "Active (Streaming on Port ${DEFAULT_STREAM_PORT})"
    else
        echo "Inactive"
    fi
}

# ----------------- Packet Sniffing & Monitoring -----------------

sniff_dns() {
    print_header "Live DNS Query Monitor (UDP/TCP Port 53)"
    local iface
    read -rp "Interface to sniff on [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"

    log_info "Capturing DNS queries on ${iface}... (Press Ctrl+C to stop)"
    sudo tcpdump -i "${iface}" -n -l -q "udp port 53 or tcp port 53"
}

sniff_http() {
    print_header "HTTP Plaintext Traffic & Credential Sniffer"
    local iface
    read -rp "Interface to sniff on [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"

    log_info "Capturing HTTP requests/responses on ${iface}... (Press Ctrl+C to stop)"
    sudo tcpdump -i "${iface}" -n -A -s 0 "tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12:1] & 0xf0)>>2)) != 0)"
}

capture_pcap_file() {
    print_header "Full Local Packet Capture (PCAP File)"
    local iface pfile
    read -rp "Interface to capture [$(detect_default_iface)]: " iface
    iface="${iface:-$(detect_default_iface)}"
    read -rp "PCAP output file [${DEFAULT_PCAP}]: " pfile
    pfile="${pfile:-$DEFAULT_PCAP}"

    log_info "Writing packet capture to: ${pfile} (Press Ctrl+C to stop)..."
    sudo tcpdump -i "${iface}" -w "${pfile}"
    log_success "Saved capture to ${pfile} ($(du -h "${pfile}" 2>/dev/null | cut -f1))"
}

# ----------------- Iptables Redirection & NAT -----------------

get_iptables() {
    if command -v iptables-legacy >/dev/null 2>&1; then
        echo "iptables-legacy"
    else
        echo "iptables"
    fi
}

redirect_port() {
    local in_port="$1"
    local dest_port="$2"
    if [[ -z "$in_port" || -z "$dest_port" ]]; then
        print_header "Iptables Port Redirection / Transparent Proxy"
        read -rp "Incoming port to intercept (e.g. 80): " in_port
        read -rp "Target local destination port (e.g. 8080): " dest_port
    fi
    [[ -z "$in_port" || -z "$dest_port" ]] && return 1

    local ipt
    ipt=$(get_iptables)
    log_info "Adding iptables PREROUTING rule: Redirect port $in_port -> $dest_port..."
    sudo "${ipt}" -t nat -A PREROUTING -p tcp --dport "$in_port" -j REDIRECT --to-ports "$dest_port"
    log_success "Port redirection active (Port ${in_port} -> ${dest_port})."
}

flush_nat_rules() {
    print_header "Flush NAT & Redirection Rules"
    local ipt
    ipt=$(get_iptables)
    sudo "${ipt}" -t nat -F PREROUTING 2>/dev/null || true
    sudo "${ipt}" -t nat -F POSTROUTING 2>/dev/null || true
    log_success "Flushed all iptables PREROUTING and POSTROUTING NAT tables."
}

status() {
    print_header "Netfilter, Sniffer & Wireshark Streamer Status"
    echo -e "Remote PCAP Streamer: ${COLOR_MAGENTA}$(streamer_status)${COLOR_RESET}"
    echo -e "Default Interface:    ${COLOR_CYAN}$(detect_default_iface)${COLOR_RESET}"
    echo
    local ipt
    ipt=$(get_iptables)
    echo "--- Active NAT PREROUTING Rules ---"
    sudo "${ipt}" -t nat -L PREROUTING -v -n 2>/dev/null || echo "N/A"
    echo
    echo "--- Active NAT POSTROUTING Rules ---"
    sudo "${ipt}" -t nat -L POSTROUTING -v -n 2>/dev/null || echo "N/A"
    echo
}

menu() {
    while true; do
        print_header "Netfilter & Traffic Interception Arsenal"
        status
        echo " 1) Live PCAP Remote Streamer [Stream to Wireshark on Workstation]"
        echo " 2) Stop PCAP Remote Streamer"
        echo " 3) Live DNS Query Monitor    [Port 53]"
        echo " 4) Live HTTP Plaintext Sniff [Port 80]"
        echo " 5) Record PCAP to Local File"
        echo " 6) Redirect Port (Transparent proxy / MITM)"
        echo " 7) Flush NAT & Redirection Rules"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start_pcap_streamer; press_enter ;;
            2) stop_pcap_streamer; press_enter ;;
            3) sniff_dns; press_enter ;;
            4) sniff_http; press_enter ;;
            5) capture_pcap_file; press_enter ;;
            6) redirect_port; press_enter ;;
            7) flush_nat_rules; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    stream)      start_pcap_streamer "${2:-$DEFAULT_STREAM_PORT}" "${3:-}" ;;
    stop-stream) stop_pcap_streamer ;;
    dns)         sniff_dns ;;
    http)        sniff_http ;;
    pcap)        capture_pcap_file ;;
    redirect)    redirect_port "${2:-}" "${3:-}" ;;
    flush)       flush_nat_rules ;;
    status)      status ;;
    menu|"")     menu ;;
    *) echo "Usage: $0 {stream [port] [iface]|stop-stream|dns|http|pcap|redirect <in_port> <out_port>|flush|status|menu}" ;;
esac
