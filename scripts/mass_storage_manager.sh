#!/usr/bin/env bash
#
# hard-tools mass_storage_manager.sh
# USB Mass Storage gadget manager for DroidSpaces Arch container.
# Uses sudo for configfs operations (passwordless assumed).
#
set -euo pipefail

# ------------------------- config -------------------------
GADGET="/config/usb_gadget/g1"
FUNC_DIR="$GADGET/functions/mass_storage.0"
CONFIG_DIR="$GADGET/configs/b.1"
UDC_FILE="$GADGET/UDC"
IMG_BASE="/storage/emulated/0/hard-tools/drive"
DEFAULT_IMG="$IMG_BASE/mass_storage.img"

# ------------------------- helpers -------------------------
sudo_cmd() { sudo sh -c "$*"; }
c_red()   { printf '\033[31m%s\033[0m\n' "$1"; }
c_green() { printf '\033[32m%s\033[0m\n' "$1"; }
c_yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
c_cyan()  { printf '\033[36m%s\033[0m\n' "$1"; }

# Get current UDC (empty if unbound)
get_udc() { sudo_cmd "cat $UDC_FILE 2>/dev/null"; }

# Detect available UDC controller (from sysfs)
detect_udc() { sudo_cmd "ls /sys/class/udc/ 2>/dev/null | head -n1"; }

# Check if mass_storage.0 is symlinked into the active config
is_linked() { sudo_cmd "[ -L $CONFIG_DIR/mass_storage.0 ] && echo yes"; }

# Safely unbind UDC (release host connection)
unbind() {
    local udc
    udc=$(get_udc)
    if [[ -n "$udc" ]]; then
        c_yellow "Unbinding from UDC: $udc"
        sudo_cmd "echo '' > $UDC_FILE"
    else
        c_yellow "Already unbound."
    fi
}

# Bind UDC (make gadget visible to host)
bind() {
    local udc_name
    udc_name=$(detect_udc)
    if [[ -z "$udc_name" ]]; then
        c_red "No UDC controller found! Check /sys/class/udc/"
        return 1
    fi
    if [[ -z "$(get_udc)" ]]; then
        c_yellow "Binding to UDC: $udc_name"
        sudo_cmd "echo '$udc_name' > $UDC_FILE"
    else
        c_green "Already bound to $(get_udc)"
    fi
}

# ------------------------- core actions -------------------------
action_status() {
    c_cyan "=== Mass Storage Status ==="
    local udc linked file ro img_size
    udc=$(get_udc)
    linked=$(is_linked)
    file=$(sudo_cmd "cat $FUNC_DIR/lun.0/file 2>/dev/null" || echo "")
    ro=$(sudo_cmd "cat $FUNC_DIR/lun.0/ro 2>/dev/null" || echo "")
    if [[ -n "$file" && -f "$file" ]]; then
        img_size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "unknown")
    else
        img_size="N/A"
    fi

    echo "UDC:            ${udc:-<unbound>}"
    echo "Linked:         ${linked:-no}"
    echo "Backing file:   ${file:-<not set>}"
    echo "Image size:     $img_size"
    echo "Read-only:      ${ro:-unknown}"
    echo
}

action_list_images() {
    c_cyan "=== Images in $IMG_BASE ==="
    ls -lh "$IMG_BASE"/*.img 2>/dev/null || echo "  (none)"
    echo
}

action_create_image() {
    local img_path size_mb fs_choice
    read -rp "Image path [$DEFAULT_IMG]: " img_path
    img_path="${img_path:-$DEFAULT_IMG}"
    mkdir -p "$(dirname "$img_path")"

    read -rp "Size in MB [512]: " size_mb
    size_mb="${size_mb:-512}"
    [[ "$size_mb" =~ ^[0-9]+$ ]] || { c_red "Invalid size."; return 1; }

    echo "Filesystem type:"
    echo "  1) FAT32 (best cross-platform)"
    echo "  2) exFAT (4GB+ files, requires exfat-utils)"
    echo "  3) ext4 (Linux-only)"
    read -rp "Choose [1]: " fs_choice
    fs_choice="${fs_choice:-1}"

    c_yellow "Creating ${size_mb}MB image at $img_path ..."
    dd if=/dev/zero of="$img_path" bs=1M count="$size_mb" status=progress

    case "$fs_choice" in
        1) mkfs.fat -F 32 "$img_path" ;;
        2) mkfs.exfat "$img_path" ;;
        3) mkfs.ext4 -F "$img_path" ;;
        *) c_red "Invalid choice"; return 1 ;;
    esac
    c_green "Image created and formatted: $img_path"
}

action_resize_image() {
    local img_path new_size
    read -rp "Image path to resize [$DEFAULT_IMG]: " img_path
    img_path="${img_path:-$DEFAULT_IMG}"
    [[ -f "$img_path" ]] || { c_red "File not found."; return 1; }

    read -rp "New size in MB: " new_size
    [[ "$new_size" =~ ^[0-9]+$ ]] || { c_red "Invalid."; return 1; }

    c_yellow "Unbinding to avoid corruption..."
    unbind
    sudo_cmd "dd if=/dev/zero of='$img_path' bs=1M count=1 seek=$((new_size - 1))"

    if command -v fatresize >/dev/null; then
        c_yellow "Growing filesystem with fatresize..."
        sudo fatresize -s "${new_size}M" "$img_path" 2>/dev/null || c_red "fatresize failed (filesystem may not be FAT)."
    else
        c_yellow "fatresize not installed. You may need to reformat after resizing."
    fi
    c_green "Image expanded to ${new_size}MB. Reformat if needed."
}

action_set_lun_file() {
    local img_path
    read -rp "Image path to attach [$DEFAULT_IMG]: " img_path
    img_path="${img_path:-$DEFAULT_IMG}"
    [[ -f "$img_path" ]] || { c_red "File not found."; return 1; }

    # Ensure we are unbound to avoid "file busy" errors
    unbind
    sudo_cmd "echo '$img_path' > $FUNC_DIR/lun.0/file"
    c_green "Backing file set to: $img_path"
    # Optionally rebind automatically? Let user decide via menu
}

action_toggle_readonly() {
    local cur
    cur=$(sudo_cmd "cat $FUNC_DIR/lun.0/ro 2>/dev/null" || echo "0")
    echo "Current read-only: $cur (0=writable, 1=read-only)"
    read -rp "Set to read-only? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo_cmd "echo 1 > $FUNC_DIR/lun.0/ro"
        c_green "Set read-only. Re-bind to apply."
    else
        sudo_cmd "echo 0 > $FUNC_DIR/lun.0/ro"
        c_green "Set writable. Re-bind to apply."
    fi
}

action_bind() {
    # Ensure symlink exists
    if [[ -z "$(is_linked)" ]]; then
        c_yellow "Creating symlink to config..."
        sudo_cmd "ln -s $FUNC_DIR $CONFIG_DIR/mass_storage.0"
    fi
    bind
    c_green "Gadget bound. Host should now detect the drive."
}

action_unbind_menu() {
    unbind
    c_green "Unbound. Host will see the device disconnect."
}

action_remove_from_config() {
    unbind
    if sudo_cmd "[ -L $CONFIG_DIR/mass_storage.0 ]"; then
        sudo_cmd "rm $CONFIG_DIR/mass_storage.0"
        c_green "Removed symlink."
    else
        c_yellow "No symlink to remove."
    fi
    # Rebind other functions (if any)
    bind
}

action_delete_image() {
    local img_path
    read -rp "Image to delete [$DEFAULT_IMG]: " img_path
    img_path="${img_path:-$DEFAULT_IMG}"
    if [[ ! -f "$img_path" ]]; then
        c_red "File not found."
        return
    fi
    read -rp "Delete $img_path permanently? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        # Unbind to release file handles
        unbind
        sudo_cmd "rm -f '$img_path'"
        c_green "Deleted."
    else
        echo "Cancelled."
    fi
}

# ------------------------- menu -------------------------
show_menu() {
    echo
    c_cyan "========================================"
    c_cyan "   Mass Storage Gadget Manager (hard-tools)"
    c_cyan "========================================"
    echo " 1) Show status"
    echo " 2) Create new image (choose size & fs)"
    echo " 3) List existing images"
    echo " 4) Resize an existing image"
    echo " 5) Set/attach backing file to LUN"
    echo " 6) Toggle read-only mode"
    echo " 7) Bind gadget (make drive appear)"
    echo " 8) Unbind gadget (make drive disappear)"
    echo " 9) Remove mass_storage from active config"
    echo "10) Delete an image file"
    echo " 0) Exit"
    echo
}

main() {
    # Ensure default image directory exists
    mkdir -p "$IMG_BASE"

    while true; do
        show_menu
        read -rp "Choice: " choice
        case "$choice" in
            1) action_status ;;
            2) action_create_image ;;
            3) action_list_images ;;
            4) action_resize_image ;;
            5) action_set_lun_file ;;
            6) action_toggle_readonly ;;
            7) action_bind ;;
            8) action_unbind_menu ;;
            9) action_remove_from_config ;;
            10) action_delete_image ;;
            0) echo "Bye!"; exit 0 ;;
            *) c_red "Invalid option." ;;
        esac
    done
}

main
