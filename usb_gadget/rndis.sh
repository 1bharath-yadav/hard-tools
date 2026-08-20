#!/usr/bin/env bash
#
# hard-tools: scripts/rndis.sh
# USB RNDIS Ethernet Adapter + DHCP/DNS Server
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="rndis.rndis"
IFACE_IP="192.168.42.1"
NETMASK="255.255.255.0"
DHCP_START="192.168.42.100"
DHCP_END="192.168.42.200"
PID_FILE="/tmp/rndis_dnsmasq.pid"
LEASE_FILE="/tmp/rndis_dnsmasq.leases"
CONF_FILE="/tmp/rndis_dnsmasq.conf"

detect_iface() {
    for iface in rndis0 usb0 usb1; do
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "$iface"
            return 0
        fi
    done
    echo "rndis0"
}

start_dhcp_server() {
    local iface="$1"
    stop_dhcp_server

    log_info "Configuring network interface ${iface} -> ${IFACE_IP}/24..."
    sudo ip link set "${iface}" up 2>/dev/null || true
    sudo ip addr flush dev "${iface}" 2>/dev/null || true
    sudo ip addr add "${IFACE_IP}/24" dev "${iface}" 2>/dev/null || true

    log_info "Creating dnsmasq DHCP configuration..."
    cat << DCOF | sudo tee "${CONF_FILE}" >/dev/null
interface=${iface}
except-interface=lo
bind-interfaces
listen-address=${IFACE_IP}
dhcp-range=${DHCP_START},${DHCP_END},12h
dhcp-option=3,${IFACE_IP}
dhcp-option=6,${IFACE_IP},8.8.8.8,1.1.1.1
dhcp-leasefile=${LEASE_FILE}
pid-file=${PID_FILE}
log-facility=/tmp/rndis_dnsmasq.log
DCOF

    log_info "Starting dnsmasq DHCP server on ${iface}..."
    sudo dnsmasq -C "${CONF_FILE}"
    
    # Enable IP forwarding and NAT
    sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
    
    # Find upstream interface (e.g. wlan0)
    local upstream
    upstream=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)
    if [[ -n "${upstream}" && "${upstream}" != "${iface}" ]]; then
        log_info "Setting up NAT forwarding through ${upstream}..."
        sudo iptables -t nat -C POSTROUTING -o "${upstream}" -j MASQUERADE 2>/dev/null || \
        sudo iptables -t nat -A POSTROUTING -o "${upstream}" -j MASQUERADE 2>/dev/null || true
    fi

    log_success "DHCP Server active on ${iface} (Host IP range: ${DHCP_START} - ${DHCP_END})"
}

stop_dhcp_server() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(sudo cat "${PID_FILE}" 2>/dev/null || true)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping dnsmasq (PID ${pid})..."
            sudo kill "${pid}" 2>/dev/null || true
        fi
        sudo rm -f "${PID_FILE}" "${CONF_FILE}" 2>/dev/null || true
    fi
    sudo pkill -f "dnsmasq.*rndis_dnsmasq" 2>/dev/null || true
}

start() {
    print_header "Starting RNDIS USB Ethernet"
    unbind_udc
    link_function "${FUNC_NAME}" "${FUNC_NAME}"
    bind_udc

    sleep 1
    local iface
    iface=$(detect_iface)
    start_dhcp_server "${iface}"
    log_success "RNDIS Ethernet is ACTIVE on ${iface}."
}

stop() {
    print_header "Stopping RNDIS USB Ethernet"
    local iface
    iface=$(detect_iface)

    stop_dhcp_server
    sudo ip link set "${iface}" down 2>/dev/null || true
    sudo ip addr flush dev "${iface}" 2>/dev/null || true

    unbind_udc
    unlink_function "${FUNC_NAME}"

    local remaining
    remaining=$(list_active_functions)
    if [[ -n "${remaining}" ]]; then
        bind_udc
    fi
    log_success "RNDIS Ethernet STOPPED."
}

status() {
    print_header "RNDIS Ethernet Status"
    local linked="No"
    if is_function_linked "${FUNC_NAME}"; then
        linked="Yes (Active)"
    fi
    local udc
    udc=$(get_udc)
    local iface
    iface=$(detect_iface)
    local iface_status="Down"
    if ip link show "$iface" 2>/dev/null | grep -q "UP"; then
        iface_status="UP"
    fi

    local dhcp_status="Inactive"
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(sudo cat "${PID_FILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
        dhcp_status="Running (PID $(sudo cat "${PID_FILE}"))"
    fi

    echo -e "Function:        ${COLOR_CYAN}${FUNC_NAME}${COLOR_RESET}"
    echo -e "Linked:          ${linked}"
    echo -e "Active UDC:      ${udc:-<unbound>}"
    echo -e "Interface:       ${iface} (${iface_status})"
    echo -e "Gateway IP:      ${IFACE_IP}"
    echo -e "DHCP Server:     ${dhcp_status}"
    echo
    echo "--- Active DHCP Leases ---"
    if [[ -f "${LEASE_FILE}" ]] && [[ -s "${LEASE_FILE}" ]]; then
        sudo cat "${LEASE_FILE}"
    else
        echo "  (No connected clients currently leased)"
    fi
    echo
}

menu() {
    while true; do
        print_header "RNDIS Ethernet Manager"
        status
        echo " 1) Start RNDIS (Enable USB Ethernet & DHCP)"
        echo " 2) Stop RNDIS (Disable USB Ethernet)"
        echo " 3) Restart DHCP Server"
        echo " 4) View Connected Client Leases"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start; press_enter ;;
            2) stop; press_enter ;;
            3)
                local iface
                iface=$(detect_iface)
                start_dhcp_server "$iface"
                press_enter ;;
            4)
                echo "--- DHCP Leases ---"
                sudo cat "${LEASE_FILE}" 2>/dev/null || echo "No leases file."
                press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    restart) stop; sleep 0.5; start ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start|stop|status|restart|menu}" ;;
esac
