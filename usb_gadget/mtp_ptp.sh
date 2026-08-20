#!/usr/bin/env bash
#
# hard-tools: scripts/mtp_ptp.sh
# USB MTP / PTP Media Transfer Protocol Gadget Switch
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

start_mtp() {
    print_header "Starting MTP (Media Transfer Protocol)"
    unbind_udc
    unlink_function "ffs.ptp"
    link_function "ffs.mtp" "ffs.mtp"
    bind_udc
    log_success "MTP Gadget mode is ACTIVE."
}

start_ptp() {
    print_header "Starting PTP (Picture Transfer Protocol)"
    unbind_udc
    unlink_function "ffs.mtp"
    link_function "ffs.ptp" "ffs.ptp"
    bind_udc
    log_success "PTP Gadget mode is ACTIVE."
}

stop() {
    print_header "Stopping MTP/PTP Gadget"
    unbind_udc
    unlink_function "ffs.mtp"
    unlink_function "ffs.ptp"

    local remaining
    remaining=$(list_active_functions)
    if [[ -n "${remaining}" ]]; then
        bind_udc
    fi
    log_success "MTP/PTP Gadget STOPPED."
}

status() {
    print_header "MTP / PTP Gadget Status"
    local mtp_linked="No"
    local ptp_linked="No"
    if is_function_linked "ffs.mtp"; then mtp_linked="Yes (Active)"; fi
    if is_function_linked "ffs.ptp"; then ptp_linked="Yes (Active)"; fi
    local udc
    udc=$(get_udc)

    echo -e "MTP (ffs.mtp):   ${mtp_linked}"
    echo -e "PTP (ffs.ptp):   ${ptp_linked}"
    echo -e "Active UDC:      ${udc:-<unbound>}"
    echo
}

menu() {
    while true; do
        print_header "MTP / PTP Gadget Manager"
        status
        echo " 1) Enable MTP (Media Transfer Mode)"
        echo " 2) Enable PTP (Camera / Photo Mode)"
        echo " 3) Stop / Disable MTP & PTP"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start_mtp; press_enter ;;
            2) start_ptp; press_enter ;;
            3) stop; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    mtp)     start_mtp ;;
    ptp)     start_ptp ;;
    stop)    stop ;;
    status)  status ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {mtp|ptp|stop|status|menu}" ;;
esac
