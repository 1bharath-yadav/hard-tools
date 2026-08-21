#!/data/data/com.termux/files/usr/bin/bash
#
# hard-tools: operator/ktrace.sh
# Linux Kernel Ftrace, Dynamic Kprobes & Low-Level Event Observability Engine
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh" 2>/dev/null || {
    COLOR_RESET="\033[0m"; COLOR_BOLD="\033[1m"; COLOR_RED="\033[31m"; COLOR_GREEN="\033[32m"; COLOR_YELLOW="\033[33m"; COLOR_CYAN="\033[36m"
    log_info() { echo -e "${COLOR_CYAN}[*]${COLOR_RESET} $*"; }
    log_success() { echo -e "${COLOR_GREEN}[+]${COLOR_RESET} $*"; }
    log_warn() { echo -e "${COLOR_YELLOW}[!]${COLOR_RESET} $*"; }
    log_error() { echo -e "${COLOR_RED}[-]${COLOR_RESET} $*"; }
    print_header() { echo -e "\n${COLOR_BOLD}=== $* ===${COLOR_RESET}\n"; }
}

TRACE_DIR="/sys/kernel/tracing"
[[ ! -d "$TRACE_DIR" ]] && TRACE_DIR="/sys/kernel/debug/tracing"

ensure_root() {
    if [[ $EUID -ne 0 ]] && ! command -v su &>/dev/null; then
        log_error "Root access (su) is required for kernel ftrace/kprobe inspection."
        exit 1
    fi
}

check_tracefs() {
    if ! su -c "test -d $TRACE_DIR" 2>/dev/null; then
        log_warn "TraceFS not found at $TRACE_DIR. Attempting mount..."
        su -c "mount -t tracefs nodev /sys/kernel/tracing 2>/dev/null || mount -t debugfs none /sys/kernel/debug 2>/dev/null" || true
    fi
}

trace_status() {
    print_header "Linux Kernel Tracing (Ftrace / Kprobes) Status"
    check_tracefs

    local tracing_on buf_kb active_events kprobes
    tracing_on=$(su -c "cat ${TRACE_DIR}/tracing_on" 2>/dev/null | tr -d '\r\n')
    buf_kb=$(su -c "cat ${TRACE_DIR}/buffer_size_kb" 2>/dev/null | head -n1 | tr -d '\r\n')
    active_events=$(su -c "grep -s -v '^#' ${TRACE_DIR}/set_event" 2>/dev/null | tr '\n' ' ')
    active_events="${active_events:-<none>}"
    kprobes=$(su -c "cat ${TRACE_DIR}/kprobe_events 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r\n')

    echo -e "  TraceFS Directory  : ${COLOR_BOLD}${TRACE_DIR}${COLOR_RESET}"
    echo -e "  Tracing State      : $([ "$tracing_on" = "1" ] && echo -e "${COLOR_GREEN}ENABLED (1)${COLOR_RESET}" || echo -e "${COLOR_YELLOW}DISABLED (0)${COLOR_RESET}")"
    echo -e "  Per-CPU Buffer Size: ${COLOR_BOLD}${buf_kb:-0} KB${COLOR_RESET}"
    echo -e "  Active Trace Events: ${COLOR_BOLD}${active_events}${COLOR_RESET}"
    echo -e "  Registered Kprobes : ${COLOR_BOLD}${kprobes:-0}${COLOR_RESET}"

    echo
    echo -e "${COLOR_BOLD}Available Event Subsystems:${COLOR_RESET}"
    su -c "cat ${TRACE_DIR}/available_events 2>/dev/null | awk -F':' '{print \$1}' | sort -u | tr '\n' ' '" 2>/dev/null || echo "None"
    echo -e "\n"
}

trace_reset() {
    print_header "Resetting Ftrace Buffer & Event Filters"
    ensure_root
    check_tracefs

    su -c "echo 0 > ${TRACE_DIR}/tracing_on" 2>/dev/null
    su -c "echo > ${TRACE_DIR}/set_event" 2>/dev/null
    su -c "echo > ${TRACE_DIR}/trace" 2>/dev/null
    su -c "echo > ${TRACE_DIR}/kprobe_events" 2>/dev/null
    log_success "Ftrace state reset and buffers flushed."
}

trace_watch_event() {
    local event_pattern="${1:-}"
    ensure_root
    check_tracefs

    [[ -z "$event_pattern" ]] && { log_error "Usage: ktrace watch <event_pattern> (e.g. 'raw_syscalls:*', 'sched:*', 'binder:*', 'net:*')"; return 1; }

    print_header "Live Streaming Kernel Events: $event_pattern"
    log_info "Configuring event filter..."

    su -c "echo 0 > ${TRACE_DIR}/tracing_on" 2>/dev/null
    su -c "echo > ${TRACE_DIR}/set_event" 2>/dev/null
    su -c "echo > ${TRACE_DIR}/trace" 2>/dev/null

    if ! su -c "echo '$event_pattern' > ${TRACE_DIR}/set_event" 2>/dev/null; then
        log_error "Failed to set event filter: $event_pattern"
        return 1
    fi

    su -c "echo 1 > ${TRACE_DIR}/tracing_on" 2>/dev/null
    log_success "Tracing active. Streaming live trace_pipe (Press Ctrl+C to stop)..."
    echo

    su -c "cat ${TRACE_DIR}/trace_pipe"
}

trace_kprobe_add() {
    local func="$1"
    ensure_root
    check_tracefs

    [[ -z "$func" ]] && { log_error "Usage: ktrace kprobe add <kernel_function>"; return 1; }

    if ! su -c "grep -qw '$func' /proc/kallsyms 2>/dev/null"; then
        log_warn "Function '$func' not found in /proc/kallsyms. Adding anyway..."
    fi

    print_header "Attaching Dynamic Kprobe to $func"
    local probe_name="p_${func}"
    
    if su -c "echo 'p:${probe_name} ${func}' >> ${TRACE_DIR}/kprobe_events" 2>/dev/null; then
        log_success "Kprobe registered: ${probe_name} -> ${func}"
        su -c "echo 'kprobes:${probe_name}' >> ${TRACE_DIR}/set_event" 2>/dev/null
        su -c "echo 1 > ${TRACE_DIR}/tracing_on" 2>/dev/null
    else
        log_error "Failed to register kprobe on '$func'."
        return 1
    fi
}

trace_kprobe_list() {
    print_header "Active Kernel Kprobes & Hit Profile"
    check_tracefs

    echo -e "${COLOR_BOLD}Kprobe Events:${COLOR_RESET}"
    su -c "cat ${TRACE_DIR}/kprobe_events 2>/dev/null" || echo "None"
    echo
    echo -e "${COLOR_BOLD}Kprobe Hit Statistics:${COLOR_RESET}"
    su -c "cat ${TRACE_DIR}/kprobe_profile 2>/dev/null" || echo "None"
    echo
}

menu() {
    while true; do
        clear 2>/dev/null || true
        trace_status
        echo -e "  ${COLOR_BOLD}Linux Kernel Observability (Ftrace / Kprobes):${COLOR_RESET}"
        echo "   1) Stream Syscall Events      (raw_syscalls:*)"
        echo "   2) Stream Binder IPC Events   (binder:*)"
        echo "   3) Stream Network Stack Events(net:*)"
        echo "   4) Stream Process Scheduler   (sched:sched_switch,sched_process_exec)"
        echo "   5) Stream Custom Event Pattern"
        echo "   6) Add Dynamic Kprobe on Function"
        echo "   7) List Active Kprobes & Hit Counters"
        echo "   8) Reset / Flush Tracing Buffers"
        echo
        echo "   0) Back to Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) trace_watch_event "raw_syscalls:*" ;;
            2) trace_watch_event "binder:*" ;;
            3) trace_watch_event "net:*" ;;
            4) trace_watch_event "sched:sched_switch sched:sched_process_exec" ;;
            5)
                read -rp "Enter event pattern (e.g. 'power:*', 'kmem:*', 'irq:*'): " ev
                trace_watch_event "$ev" ;;
            6)
                read -rp "Enter kernel function name (e.g. 'dwc3_ep0_interrupt', 'uhid_char_write'): " fn
                trace_kprobe_add "$fn"
                read -rp "Press Enter to continue..." ;;
            7) trace_kprobe_list; read -rp "Press Enter to continue..." ;;
            8) trace_reset; read -rp "Press Enter to continue..." ;;
            0) break ;;
            *) sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    status)     trace_status ;;
    reset|clean|clear) trace_reset ;;
    watch)      trace_watch_event "${2:-raw_syscalls:*}" ;;
    syscalls)   trace_watch_event "raw_syscalls:*" ;;
    binder)     trace_watch_event "binder:*" ;;
    net)        trace_watch_event "net:*" ;;
    sched)      trace_watch_event "sched:sched_switch sched:sched_process_exec" ;;
    kprobe)
        case "${2:-}" in
            add)    trace_kprobe_add "${3:-}" ;;
            list)   trace_kprobe_list ;;
            clear)  trace_reset ;;
            *)      echo "Usage: $0 kprobe {add <func>|list|clear}" ;;
        esac ;;
    menu|"")    menu ;;
    *) echo "Usage: $0 {status|reset|watch <event>|syscalls|binder|net|sched|kprobe {add|list|clear}|menu}" ;;
esac
