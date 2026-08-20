#!/usr/bin/env bash
#
# hard-tools: scripts/session.sh
# Terminal-native session recorder and artifact logger
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SESSIONS_DIR="${ROOT_DIR}/sessions"
LIB_DIR="${ROOT_DIR}/lib"
source "${LIB_DIR}/utils.sh"

mkdir -p "$SESSIONS_DIR"

start_session() {
    local session_id
    session_id=$(date +"%Y-%m-%d_%H-%M-%S")
    local session_path="${SESSIONS_DIR}/${session_id}"
    mkdir -p "${session_path}/artifacts"

    print_header "Starting Recorded Session: ${session_id}"
    log_info "Session directory: ${session_path}"
    log_info "All commands and outputs in this subshell will be recorded."
    echo "Type 'exit' when finished to close session."
    echo

    cat << SESSION_INFO > "${session_path}/session_meta.txt"
Session ID: ${session_id}
Started At: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Kernel: $(uname -a)
User: $(whoami)
SESSION_INFO

    if command -v script >/dev/null 2>&1; then
        script -q -c "bash --norc -i" "${session_path}/terminal.log"
    else
        bash -i 2>&1 | tee "${session_path}/terminal.log"
    fi

    echo "Ended At: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${session_path}/session_meta.txt"
    log_success "Session ${session_id} recorded successfully."
}

list_sessions() {
    print_header "Recorded Sessions Log"
    if [[ ! -d "$SESSIONS_DIR" ]] || [[ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
        echo "No sessions recorded yet."
        echo
        return
    fi

    for sess in "$SESSIONS_DIR"/*; do
        if [[ -d "$sess" ]]; then
            local sname
            sname=$(basename "$sess")
            local size
            size=$(du -sh "$sess" | awk '{print $1}')
            echo -e "  * ${COLOR_CYAN}${sname}${COLOR_RESET} (${size})"
            if [[ -f "${sess}/session_meta.txt" ]]; then
                sed 's/^/      /' "${sess}/session_meta.txt"
            fi
            echo
        fi
    done
}

menu() {
    while true; do
        print_header "Session Logger & Reproducibility"
        echo " 1) Start New Recorded Session"
        echo " 2) List Past Sessions"
        echo " 0) Back"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start_session; press_enter ;;
            2) list_sessions; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start_session ;;
    list)    list_sessions ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start|list|menu}" ;;
esac
