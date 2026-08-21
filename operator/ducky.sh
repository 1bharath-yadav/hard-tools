#!/usr/bin/env bash
#
# hard-tools: operator/ducky.sh
# Hak5 DuckyScript 3.0 Payload Arsenal & Keystroke Injection Engine
# Supports Windows, Linux, and macOS multi-stage payloads with human typing jitter.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

USB_GADGET_SCRIPT="${ROOT_DIR}/usb_gadget/hid.sh"
HID_ENGINE="${LIB_DIR}/hid_engine.py"

PAYLOAD_DIRS=(
    "${PAYLOADS_DIR}"
    "${LOCAL_PAYLOADS_DIR}"
    "${LOCAL_PAYLOADS_DIR}/windows"
    "${LOCAL_PAYLOADS_DIR}/linux"
    "${LOCAL_PAYLOADS_DIR}/macos"
)

ensure_hid_ready() {
    if ! is_function_linked "hid.keyboard"; then
        log_warn "HID Keyboard not linked. Starting USB Gadget HID subsystem..."
        sudo bash "${USB_GADGET_SCRIPT}" start
        sleep 1
    fi
}

resolve_payload_file() {
    local target="$1"
    if [[ -f "$target" ]]; then
        echo "$target"
        return 0
    fi

    # Search in directories
    for dir in "${PAYLOAD_DIRS[@]}"; do
        if [[ -f "${dir}/${target}" ]]; then
            echo "${dir}/${target}"
            return 0
        fi
        if [[ -f "${dir}/${target}.duck" ]]; then
            echo "${dir}/${target}.duck"
            return 0
        fi
    done
    return 1
}

list_payloads_by_category() {
    local os_filter="${1:-all}"
    print_header "DuckyScript 3.0 Weaponized Payload Arsenal [Filter: ${os_filter^^}]"

    local found=0
    local target_dirs=()

    case "$os_filter" in
        windows|win)
            target_dirs=("${LOCAL_PAYLOADS_DIR}/windows") ;;
        linux|lin)
            target_dirs=("${LOCAL_PAYLOADS_DIR}/linux") ;;
        macos|mac)
            target_dirs=("${LOCAL_PAYLOADS_DIR}/macos") ;;
        *)
            target_dirs=("${LOCAL_PAYLOADS_DIR}/windows" "${LOCAL_PAYLOADS_DIR}/linux" "${LOCAL_PAYLOADS_DIR}/macos" "${LOCAL_PAYLOADS_DIR}" "${PAYLOADS_DIR}") ;;
    esac

    for dir in "${target_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local category
            category=$(basename "$dir")
            echo -e "${COLOR_CYAN}--- [${category^^}] Location: ${dir} ---${COLOR_RESET}"
            for f in "$dir"/*.duck "$dir"/*.txt; do
                if [[ -f "$f" ]]; then
                    local size
                    size=$(du -h "$f" 2>/dev/null | cut -f1)
                    local desc
                    desc=$(grep "^REM" "$f" 2>/dev/null | head -n1 | sed 's/^REM //')
                    printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} (%-4s) : %s\n" "$(basename "$f")" "$size" "${desc:-<No description>}"
                    found=1
                fi
            done
            echo
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "  (No payloads found for category ${os_filter})"
    fi
}

run_payload() {
    local pinput="$1"
    local jitter_flag="${2:-no}"
    local delay_sec="${3:-3}"

    local pfile
    pfile=$(resolve_payload_file "$pinput") || {
        log_error "Payload '$pinput' not found in any payload directories!"
        return 1
    }

    ensure_hid_ready

    print_header "Arming Payload: $(basename "$pfile")"
    log_info "Payload file: ${pfile}"
    if [[ "$jitter_flag" == "jitter" || "$jitter_flag" == "yes" || "$jitter_flag" == "true" ]]; then
        log_info "Human typing jitter: ${COLOR_GREEN}ENABLED (anti-EDR / behavioral evasion)${COLOR_RESET}"
    else
        log_info "Human typing jitter: ${COLOR_YELLOW}DISABLED (standard speed)${COLOR_RESET}"
    fi

    echo
    echo -e "${COLOR_BOLD}Focus target host window! Injecting in ${delay_sec} seconds...${COLOR_RESET}"
    for ((i=delay_sec; i>0; i--)); do
        printf "  [*] T-minus %d...\n" "$i"
        sleep 1
    done
    printf "${COLOR_RED}${COLOR_BOLD}  [>>> FIRE! Keystroke injection running... <<<]${COLOR_RESET}\n\n"

    if [[ "$jitter_flag" == "jitter" || "$jitter_flag" == "yes" || "$jitter_flag" == "true" ]]; then
        sudo python3 "${HID_ENGINE}" ducky "$pfile" --jitter
    else
        sudo python3 "${HID_ENGINE}" ducky "$pfile"
    fi

    log_success "Payload '$(basename "$pfile")' executed successfully."
}

view_payload() {
    local pinput="$1"
    local pfile
    pfile=$(resolve_payload_file "$pinput") || {
        log_error "Payload '$pinput' not found!"
        return 1
    }

    print_header "Payload Source: $(basename "$pfile")"
    echo -e "${COLOR_DIM}Path: ${pfile}${COLOR_RESET}\n"
    nl -ba "$pfile"
    echo
}

interactive_create() {
    print_header "Create New DuckyScript 3.0 Payload"
    echo "Select target OS category:"
    echo " 1) Windows"
    echo " 2) Linux"
    echo " 3) macOS"
    echo " 4) Root / General"
    read -rp "Category [1-4]: " cat_opt

    local target_dir="${LOCAL_PAYLOADS_DIR}"
    case "$cat_opt" in
        1) target_dir="${LOCAL_PAYLOADS_DIR}/windows" ;;
        2) target_dir="${LOCAL_PAYLOADS_DIR}/linux" ;;
        3) target_dir="${LOCAL_PAYLOADS_DIR}/macos" ;;
    esac
    ensure_dir "$target_dir"

    read -rp "Payload filename (e.g. custom_exploit.duck): " pname
    [[ -z "$pname" ]] && return 1
    [[ "$pname" != *.duck ]] && pname="${pname}.duck"

    local full_path="${target_dir}/${pname}"
    echo
    echo "Enter DuckyScript 3.0 instructions (type 'EOF' on a new line when done):"
    cat << 'HELPEOF'
DuckyScript 3.0 Commands:
  REM <comment>
  DELAY <milliseconds>
  STRING <text>
  STRINGLN <text>      (types string + sends ENTER)
  JITTER 5 25          (human keystroke jitter range)
  GUI r / ENTER / TAB / ESCAPE / BACKSPACE
  CTRL ALT t / GUI SPACE
  REPEAT <count>
HELPEOF
    echo

    > "$full_path"
    while IFS= read -r line; do
        [[ "$line" == "EOF" ]] && break
        echo "$line" >> "$full_path"
    done
    log_success "Saved payload to: $full_path"
}

select_and_fire_menu() {
    local os_filter="$1"
    list_payloads_by_category "$os_filter"
    read -rp "Enter payload name to execute (or Enter to cancel): " pchoice
    [[ -z "$pchoice" ]] && return 0

    echo
    read -rp "Enable human keystroke jitter? (y/N): " jchoice
    local jitter="no"
    [[ "$jchoice" =~ ^[Yy]$ ]] && jitter="jitter"

    read -rp "Countdown delay in seconds [3]: " dchoice
    local dsec="${dchoice:-3}"

    run_payload "$pchoice" "$jitter" "$dsec"
    press_enter
}

menu() {
    while true; do
        print_header "Rubber Ducky 3.0 Weaponized Payload Suite"
        echo " 1) Windows Staged Payloads    [Recon, Wi-Fi Extract, UAC]"
        echo " 2) Linux Staged Payloads      [Recon, SSH Grab, Sudo Test]"
        echo " 3) macOS Staged Payloads      [Recon, Terminal Exec, Wi-Fi]"
        echo " 4) View All Available Payloads"
        echo " 5) View Payload Source Code"
        echo " 6) Create New DuckyScript Payload"
        echo " 7) Verify / Start Virtual HID Keyboard"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) select_and_fire_menu "windows" ;;
            2) select_and_fire_menu "linux" ;;
            3) select_and_fire_menu "macos" ;;
            4)
                list_payloads_by_category "all"
                read -rp "Execute a payload? Enter name (or Enter to go back): " pchoice
                if [[ -n "$pchoice" ]]; then
                    run_payload "$pchoice" "no" 3
                    press_enter
                fi ;;
            5)
                list_payloads_by_category "all"
                read -rp "Enter payload name to view: " pchoice
                if [[ -n "$pchoice" ]]; then
                    view_payload "$pchoice"
                fi
                press_enter ;;
            6) interactive_create; press_enter ;;
            7) sudo bash "${USB_GADGET_SCRIPT}" start; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    run)     run_payload "${2:-}" "${3:-no}" "${4:-3}" ;;
    list)    list_payloads_by_category "${2:-all}" ;;
    view)    view_payload "${2:-}" ;;
    create)  interactive_create ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {run <payload> [jitter] [delay_sec]|list [win|lin|mac|all]|view <payload>|create|menu}" ;;
esac
