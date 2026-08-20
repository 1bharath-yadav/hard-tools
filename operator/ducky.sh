#!/usr/bin/env bash
#
# hard-tools: scripts/ducky.sh
# Hak5 DuckyScript Payload Manager & Executor
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

USB_GADGET_SCRIPT="${SCRIPT_DIR}/../usb_gadget/hid.sh"
HID_ENGINE="${LIB_DIR}/hid_engine.py"

ensure_hid_ready() {
    if ! is_function_linked "hid.keyboard"; then
        log_warn "HID Keyboard not linked. Starting USB Gadget HID..."
        sudo bash "${USB_GADGET_SCRIPT}" start
        sleep 1
    fi
}

list_payloads() {
    print_header "Available DuckyScript Payloads"
    local found=0
    for dir in "${PAYLOADS_DIR}" "${LOCAL_PAYLOADS_DIR}"; do
        if [[ -d "$dir" ]]; then
            echo -e "${COLOR_CYAN}Directory: ${dir}${COLOR_RESET}"
            for f in "$dir"/*.duck "$dir"/*.txt; do
                if [[ -f "$f" ]]; then
                    printf "  * %s (%s)\n" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
                    found=1
                fi
            done
        fi
    done
    if [[ $found -eq 0 ]]; then
        echo "  (No .duck files found)"
    fi
    echo
}

run_payload() {
    local payload="$1"
    if [[ ! -f "$payload" ]]; then
        # Search in PAYLOADS_DIR and LOCAL_PAYLOADS_DIR
        if [[ -f "${PAYLOADS_DIR}/${payload}" ]]; then
            payload="${PAYLOADS_DIR}/${payload}"
        elif [[ -f "${LOCAL_PAYLOADS_DIR}/${payload}" ]]; then
            payload="${LOCAL_PAYLOADS_DIR}/${payload}"
        else
            log_error "Payload '$payload' not found!"
            return 1
        fi
    fi

    ensure_hid_ready

    print_header "Executing Payload: $(basename "$payload")"
    log_info "Payload location: $payload"
    echo "Starting in 3 seconds (Focus host target window!)..."
    sleep 1; echo "2..."; sleep 1; echo "1..."; sleep 1; echo "FIRE!"

    python3 "${HID_ENGINE}" ducky "$payload"
    log_success "Payload execution completed."
}

view_payload() {
    local payload="$1"
    if [[ ! -f "$payload" ]]; then
        if [[ -f "${PAYLOADS_DIR}/${payload}" ]]; then
            payload="${PAYLOADS_DIR}/${payload}"
        elif [[ -f "${LOCAL_PAYLOADS_DIR}/${payload}" ]]; then
            payload="${LOCAL_PAYLOADS_DIR}/${payload}"
        else
            log_error "Payload '$payload' not found!"
            return 1
        fi
    fi
    print_header "Payload Content: $(basename "$payload")"
    cat "$payload"
    echo
}

interactive_create() {
    print_header "Create New DuckyScript Payload"
    read -rp "Payload name (e.g. test.duck): " pname
    [[ -z "$pname" ]] && return 1
    [[ "$pname" != *.duck ]] && pname="${pname}.duck"

    local pfile="${PAYLOADS_DIR}/${pname}"
    echo "Enter DuckyScript lines (type 'EOF' on a new line when done):"
    cat << 'HELPEOF'
Commands:
  STRING <text>
  DELAY <ms>
  GUI r / ENTER / TAB / ESCAPE / BACKSPACE
  CTRL ALT t
HELPEOF
    echo

    > "$pfile"
    while IFS= read -r line; do
        [[ "$line" == "EOF" ]] && break
        echo "$line" >> "$pfile"
    done
    log_success "Saved payload to: $pfile"
}

menu() {
    while true; do
        print_header "Rubber Ducky Payload Arsenal"
        list_payloads
        echo " 1) Run a Payload"
        echo " 2) View Payload Content"
        echo " 3) Create New Payload"
        echo " 4) Ensure / Start HID Keyboard"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1)
                read -rp "Enter payload filename or path: " pchoice
                if [[ -n "$pchoice" ]]; then
                    run_payload "$pchoice"
                fi
                press_enter ;;
            2)
                read -rp "Enter payload filename to view: " pchoice
                if [[ -n "$pchoice" ]]; then
                    view_payload "$pchoice"
                fi
                press_enter ;;
            3) interactive_create; press_enter ;;
            4) sudo bash "${USB_GADGET_SCRIPT}" start; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    run)     run_payload "${2:-}" ;;
    list)    list_payloads ;;
    view)    view_payload "${2:-}" ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {run <payload>|list|view <payload>|menu}" ;;
esac
