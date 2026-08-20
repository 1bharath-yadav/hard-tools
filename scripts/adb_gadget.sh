#!/usr/bin/env bash
#
# hard-tools: scripts/adb_gadget.sh
# Manage ADB (Android Debug Bridge) USB Gadget Function
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="ffs.adb"
LINK_NAME="function0"

start() {
    print_header "Starting ADB Gadget Function"
    unbind_udc
    link_function "${FUNC_NAME}" "${LINK_NAME}"
    bind_udc
    log_success "ADB gadget mode is now ACTIVE."
}

stop() {
    print_header "Stopping ADB Gadget Function"
    unbind_udc
    unlink_function "${LINK_NAME}"
    unlink_function "${FUNC_NAME}"
    # If other functions remain linked, rebind
    local remaining
    remaining=$(list_active_functions)
    if [[ -n "${remaining}" ]]; then
        bind_udc
    fi
    log_success "ADB gadget mode STOPPED."
}

status() {
    print_header "ADB Gadget Status"
    local linked="No"
    if is_function_linked "${LINK_NAME}" || is_function_linked "${FUNC_NAME}"; then
        linked="Yes (Active)"
    fi
    local udc
    udc=$(get_udc)

    echo -e "Function:      ${COLOR_CYAN}${FUNC_NAME}${COLOR_RESET}"
    echo -e "Linked:        ${linked}"
    echo -e "Active UDC:    ${udc:-<unbound>}"
    echo -e "ConfigFS Node: ${FUNCTIONS_DIR}/${FUNC_NAME}"
    echo
}

menu() {
    while true; do
        print_header "ADB Gadget Manager"
        status
        echo " 1) Start / Enable ADB"
        echo " 2) Stop / Disable ADB"
        echo " 3) Refresh Status"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start; press_enter ;;
            2) stop; press_enter ;;
            3) ;;
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
