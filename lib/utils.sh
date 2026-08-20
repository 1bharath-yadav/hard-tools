#!/usr/bin/env bash
#
# hard-tools: lib/utils.sh
# Core utility functions for USB ConfigFS Gadget manipulation & system tools.
#

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_MAGENTA="\033[1;35m"
COLOR_CYAN="\033[1;36m"
COLOR_WHITE="\033[1;37m"
COLOR_BOLD="\033[1m"
COLOR_DIM="\033[2m"

# Print colored messages
c_red()     { printf "${COLOR_RED}%s${COLOR_RESET}\n" "$*"; }
c_green()   { printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$*"; }
c_yellow()  { printf "${COLOR_YELLOW}%s${COLOR_RESET}\n" "$*"; }
c_blue()    { printf "${COLOR_BLUE}%s${COLOR_RESET}\n" "$*"; }
c_cyan()    { printf "${COLOR_CYAN}%s${COLOR_RESET}\n" "$*"; }
c_magenta() { printf "${COLOR_MAGENTA}%s${COLOR_RESET}\n" "$*"; }
c_dim()     { printf "${COLOR_DIM}%s${COLOR_RESET}\n" "$*"; }

# Logging functions
log_info()    { printf "${COLOR_CYAN}[*]${COLOR_RESET} %s\n" "$*"; }
log_success() { printf "${COLOR_GREEN}[+]${COLOR_RESET} %s\n" "$*"; }
log_warn()    { printf "${COLOR_YELLOW}[!]${COLOR_RESET} %s\n" "$*"; }
log_error()   { printf "${COLOR_RED}[-]${COLOR_RESET} %s\n" "$*"; }

# Paths & Locations
GADGET_DIR="/config/usb_gadget/g1"
CONFIG_DIR="${GADGET_DIR}/configs/b.1"
FUNCTIONS_DIR="${GADGET_DIR}/functions"
UDC_FILE="${GADGET_DIR}/UDC"

STORAGE_DIR="/storage/emulated/0/hard-tools"
IMAGES_DIR="${STORAGE_DIR}/drive"
PAYLOADS_DIR="${STORAGE_DIR}/payloads"
LOCAL_PAYLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/payloads"
LOCAL_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

# Fallback dirs
[[ ! -d "${IMAGES_DIR}" ]] && IMAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/images"
[[ ! -d "${PAYLOADS_DIR}" ]] && PAYLOADS_DIR="${LOCAL_PAYLOADS_DIR}"

# Safe Sudo wrapper
sudo_cmd() {
    sudo sh -c "$*"
}

# ----------------- UDC Functions -----------------

get_udc() {
    sudo cat "${UDC_FILE}" 2>/dev/null || true
}

detect_udc() {
    # Prefer hardware UDC (e.g. dwc3, chipidea) over dummy_udc
    local hw_udc
    hw_udc=$(ls /sys/class/udc/ 2>/dev/null | grep -v "dummy" | head -n1 || true)
    if [[ -z "${hw_udc}" ]]; then
        hw_udc=$(ls /sys/class/udc/ 2>/dev/null | head -n1 || true)
    fi
    echo "${hw_udc}"
}

is_gadget_bound() {
    local cur_udc
    cur_udc=$(get_udc)
    [[ -n "${cur_udc}" ]]
}

unbind_udc() {
    local cur_udc
    cur_udc=$(get_udc)
    if [[ -n "${cur_udc}" ]]; then
        log_info "Unbinding gadget from UDC (${cur_udc})..."
        sudo sh -c "echo '' > '${UDC_FILE}'" 2>/dev/null || true
        sleep 0.3
        if is_gadget_bound; then
            log_warn "UDC still bound, retrying forced unbind..."
            sudo sh -c "echo '' > '${UDC_FILE}'" 2>/dev/null || true
        fi
        log_success "Gadget unbound."
    else
        log_info "Gadget already unbound."
    fi
}

bind_udc() {
    local target_udc
    target_udc=$(detect_udc)
    if [[ -z "${target_udc}" ]]; then
        log_error "No UDC hardware controller found in /sys/class/udc/!"
        return 1
    fi

    local cur_udc
    cur_udc=$(get_udc)
    if [[ -n "${cur_udc}" ]]; then
        if [[ "${cur_udc}" == "${target_udc}" ]]; then
            log_info "Gadget already bound to ${target_udc}."
            return 0
        else
            unbind_udc
        fi
    fi

    log_info "Binding gadget to UDC: ${target_udc}..."
    if sudo sh -c "echo '${target_udc}' > '${UDC_FILE}'"; then
        sleep 0.5
        log_success "Gadget successfully bound to ${target_udc}."
        return 0
    else
        log_error "Failed to bind to UDC ${target_udc}!"
        return 1
    fi
}

# ----------------- ConfigFS Symlink Helpers -----------------

is_function_linked() {
    local func_name="$1"
    # Can match exact name or symlink name in configs/b.1
    if sudo test -L "${CONFIG_DIR}/${func_name}"; then
        return 0
    fi
    # Also check if any symlink targets this function
    for link in $(sudo ls "${CONFIG_DIR}" 2>/dev/null); do
        local target
        target=$(sudo readlink "${CONFIG_DIR}/${link}" 2>/dev/null || true)
        if [[ "${target}" == *"${func_name}"* || "${link}" == "${func_name}" ]]; then
            return 0
        fi
    done
    return 1
}

link_function() {
    local func_name="$1"
    local link_name="${2:-$func_name}"
    local func_path="${FUNCTIONS_DIR}/${func_name}"

    if [[ ! -d "${func_path}" ]]; then
        log_error "Function directory '${func_path}' does not exist!"
        return 1
    fi

    if is_function_linked "${link_name}"; then
        log_info "Function '${func_name}' is already linked as '${link_name}'."
        return 0
    fi

    log_info "Linking ${func_name} -> ${CONFIG_DIR}/${link_name}..."
    if sudo ln -s "${func_path}" "${CONFIG_DIR}/${link_name}"; then
        log_success "Linked ${link_name}."
        return 0
    else
        log_error "Failed to link ${func_name}!"
        return 1
    fi
}

unlink_function() {
    local link_name="$1"
    local found=0

    # Try direct link name
    if sudo test -L "${CONFIG_DIR}/${link_name}"; then
        sudo rm -f "${CONFIG_DIR}/${link_name}"
        log_success "Unlinked ${link_name}."
        found=1
    fi

    # Also search for symlinks matching target
    for l in $(sudo ls "${CONFIG_DIR}" 2>/dev/null); do
        local target
        target=$(sudo readlink "${CONFIG_DIR}/${l}" 2>/dev/null || true)
        if [[ "${target}" == *"${link_name}"* || "${l}" == "${link_name}" ]]; then
            sudo rm -f "${CONFIG_DIR}/${l}"
            log_success "Unlinked matching symlink ${l}."
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        log_info "Symlink for '${link_name}' was not present."
    fi
    return 0
}

list_active_functions() {
    local funcs=()
    for l in $(sudo ls "${CONFIG_DIR}" 2>/dev/null); do
        if sudo test -L "${CONFIG_DIR}/${l}"; then
            local target
            target=$(sudo readlink "${CONFIG_DIR}/${l}" 2>/dev/null || true)
            funcs+=("${l} -> $(basename "${target}")")
        fi
    done
    echo "${funcs[@]}"
}

# ----------------- UI & Display Helpers -----------------

print_header() {
    local title="$1"
    echo
    printf "${COLOR_CYAN}====================================================${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_WHITE}  %s${COLOR_RESET}\n" "${title}"
    printf "${COLOR_CYAN}====================================================${COLOR_RESET}\n"
}

press_enter() {
    echo
    printf "${COLOR_DIM}Press [Enter] to continue...${COLOR_RESET}"
    read -r
}

# Ensure directory helper
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir"
    fi
}
