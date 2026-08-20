#!/usr/bin/env bash
#
# hard-tools: scripts/uvc_webcam.sh
# USB UVC Webcam Gadget & Video Streamer
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="uvc.0"
PID_STREAM="/tmp/uvc_stream.pid"

detect_uvc_video_dev() {
    # Match UVC gadget output node (e.g. /dev/video2 or group video)
    for dev in /dev/video2 /dev/video3 /dev/video1 /dev/video0; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done
    echo "/dev/video2"
}

start() {
    print_header "Starting UVC USB Webcam Gadget"
    unbind_udc
    link_function "${FUNC_NAME}" "${FUNC_NAME}"
    bind_udc
    sleep 0.5
    log_success "UVC Webcam Gadget is ACTIVE. Host should detect a USB Camera."
}

stop() {
    print_header "Stopping UVC USB Webcam Gadget"
    stop_stream
    unbind_udc
    unlink_function "${FUNC_NAME}"

    local remaining
    remaining=$(list_active_functions)
    if [[ -n "${remaining}" ]]; then
        bind_udc
    fi
    log_success "UVC Webcam Gadget STOPPED."
}

stop_stream() {
    if [[ -f "${PID_STREAM}" ]]; then
        local pid
        pid=$(cat "${PID_STREAM}" 2>/dev/null || true)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping video streamer (PID ${pid})..."
            kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${PID_STREAM}" 2>/dev/null || true
    fi
    pkill -f "ffmpeg.*testsrc" 2>/dev/null || true
}

stream_test_pattern() {
    print_header "Streaming Test Pattern to UVC Camera"
    local dev
    dev=$(detect_uvc_video_dev)
    stop_stream

    log_info "Launching SMPTE color bars & clock pattern on ${dev}..."
    ffmpeg -re -f lavfi -i testsrc=size=640x480:rate=30 -vcodec rawvideo -pix_fmt yuyv422 -f v4l2 "${dev}" >/tmp/uvc_ffmpeg.log 2>&1 &
    echo $! > "${PID_STREAM}"
    log_success "Test pattern stream active. Check with camera viewer on host (e.g. OBS, guvcview, or Windows Camera app)."
}

stream_custom_file() {
    local vfile="$1"
    if [[ ! -f "$vfile" ]]; then
        log_error "Video file '$vfile' not found!"
        return 1
    fi
    local dev
    dev=$(detect_uvc_video_dev)
    stop_stream

    log_info "Streaming '$vfile' to ${dev} (loop mode)..."
    ffmpeg -re -stream_loop -1 -i "${vfile}" -vcodec rawvideo -pix_fmt yuyv422 -s 640x480 -f v4l2 "${dev}" >/tmp/uvc_ffmpeg.log 2>&1 &
    echo $! > "${PID_STREAM}"
    log_success "Custom video stream active."
}

status() {
    print_header "UVC USB Webcam Status"
    local linked="No"
    if is_function_linked "${FUNC_NAME}"; then
        linked="Yes (Active)"
    fi
    local udc
    udc=$(get_udc)
    local vdev
    vdev=$(detect_uvc_video_dev)

    local stream_status="Inactive"
    if [[ -f "${PID_STREAM}" ]] && kill -0 "$(cat "${PID_STREAM}" 2>/dev/null || echo 0)" 2>/dev/null; then
        stream_status="Streaming (PID $(cat "${PID_STREAM}"))"
    fi

    echo -e "Function:        ${COLOR_CYAN}${FUNC_NAME}${COLOR_RESET}"
    echo -e "Linked:          ${linked}"
    echo -e "Active UDC:      ${udc:-<unbound>}"
    echo -e "Video Node:      ${vdev}"
    echo -e "Stream State:    ${stream_status}"
    echo
}

menu() {
    while true; do
        print_header "UVC USB Webcam Manager"
        status
        echo " 1) Start UVC Gadget (Mount USB Camera)"
        echo " 2) Stop UVC Gadget"
        echo " 3) Stream Test Pattern (Color bars / timer)"
        echo " 4) Stream Custom Video File"
        echo " 5) Stop Active Video Stream"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start; press_enter ;;
            2) stop; press_enter ;;
            3) stream_test_pattern; press_enter ;;
            4)
                read -rp "Enter video file path (mp4/mkv/avi): " vpath
                if [[ -n "$vpath" ]]; then
                    stream_custom_file "$vpath"
                fi
                press_enter ;;
            5) stop_stream; log_success "Stream stopped."; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    stream)  stream_test_pattern ;;
    file)    stream_custom_file "${2:-}" ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start|stop|status|stream|file <path>|menu}" ;;
esac
