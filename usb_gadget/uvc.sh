#!/usr/bin/env bash
#
# hard-tools: usb_gadget/uvc.sh
# USB UVC 1.00 Webcam Gadget & Video Streamer
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"
source "${LIB_DIR}/utils.sh"

FUNC_NAME="uvc.0"
PID_STREAM="/tmp/uvc_stream.pid"
FRAME_PATH="/dev/shm/uvc_frame.raw"
[[ ! -d "/dev/shm" ]] && FRAME_PATH="/tmp/uvc_frame.raw"

detect_uvc_video_dev() {
    for sysdev in /sys/class/video4linux/video*; do
        if [[ -d "$sysdev" ]]; then
            local name
            name=$(cat "${sysdev}/name" 2>/dev/null || true)
            if [[ "$name" == *"gadget"* || "$name" == *"dwc3"* || "$name" == *"uvc"* || "$name" == *"g_uvc"* ]]; then
                echo "/dev/$(basename "$sysdev")"
                return 0
            fi
        fi
    done
    echo "/dev/video2"
}

is_stream_running() {
    sudo pgrep -f "uvc_daemon" >/dev/null 2>&1
}

start() {
    print_header "Starting UVC USB Webcam Gadget"

    local daemon_bin="${LIB_DIR}/uvc_daemon"
    if [[ ! -x "$daemon_bin" ]] || [[ "${LIB_DIR}/uvc_daemon.c" -nt "$daemon_bin" ]]; then
        log_info "Compiling UVC Gadget Daemon..."
        gcc -O2 "${LIB_DIR}/uvc_daemon.c" -o "${daemon_bin}" 2>/dev/null || true
    fi

    stop_stream
    unbind_udc

    for lnk in "${CONFIG_DIR}"/*; do
        [[ -L "$lnk" ]] && sudo rm -f "$lnk"
    done

    # Set IAD USB Video Device Class descriptors (Video Class 0xEF, SubClass 0x02, Protocol 0x01)
    sudo sh -c "echo 0xef > '${GADGET_DIR}/bDeviceClass' 2>/dev/null || true"
    sudo sh -c "echo 0x02 > '${GADGET_DIR}/bDeviceSubClass' 2>/dev/null || true"
    sudo sh -c "echo 0x01 > '${GADGET_DIR}/bDeviceProtocol' 2>/dev/null || true"

    link_function "${FUNC_NAME}" "${FUNC_NAME}"
    bind_udc

    local vdev
    vdev=$(detect_uvc_video_dev)
    log_info "Launching UVC Event Daemon on ${vdev}..."
    sudo sh -c "\"${daemon_bin}\" \"${vdev}\" >/tmp/uvc_daemon.log 2>&1 &"
    echo $! > "${PID_STREAM}"
    sleep 0.3

    log_success "UVC Webcam Gadget is ACTIVE on ${vdev}. Ready for host requests."
}

stop() {
    print_header "Stopping UVC USB Webcam Gadget"
    stop_stream
    unbind_udc
    unlink_function "${FUNC_NAME}"

    sudo sh -c "echo 0x00 > '${GADGET_DIR}/bDeviceClass' 2>/dev/null || true"
    sudo sh -c "echo 0x00 > '${GADGET_DIR}/bDeviceSubClass' 2>/dev/null || true"
    sudo sh -c "echo 0x00 > '${GADGET_DIR}/bDeviceProtocol' 2>/dev/null || true"

    log_success "UVC Webcam Gadget STOPPED."
}

stop_stream() {
    if [[ -f "${PID_STREAM}" ]]; then
        local pid
        pid=$(cat "${PID_STREAM}" 2>/dev/null || true)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping UVC daemon (PID ${pid})..."
            sudo kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${PID_STREAM}" 2>/dev/null || true
    fi
    sudo pkill -f "uvc_daemon" 2>/dev/null || true
    sudo pkill -f "raw_sink.py" 2>/dev/null || true
    sudo pkill -f "screenrecord" 2>/dev/null || true
    rm -f "${FRAME_PATH}" "/tmp/uvc_frame.raw" "/dev/shm/uvc_frame.raw" 2>/dev/null || true
}

stream_test_pattern() {
    print_header "Streaming SMPTE Test Pattern to UVC Camera"
    # Remove raw frame file so daemon seamlessly outputs SMPTE color bars
    sudo pkill -f "raw_sink.py" 2>/dev/null || true
    rm -f "${FRAME_PATH}" "/tmp/uvc_frame.raw" "/dev/shm/uvc_frame.raw" 2>/dev/null || true

    if ! is_function_linked "${FUNC_NAME}"; then
        start
    else
        if ! is_stream_running; then
            local daemon_bin="${LIB_DIR}/uvc_daemon"
            local vdev
            vdev=$(detect_uvc_video_dev)
            sudo sh -c "\"${daemon_bin}\" \"${vdev}\" >/tmp/uvc_daemon.log 2>&1 &"
            echo $! > "${PID_STREAM}"
            sleep 0.5
        fi
        log_success "UVC SMPTE Test Pattern ACTIVE on $(detect_uvc_video_dev)."
    fi
}

stream_camera() {
    print_header "Streaming Live Android Camera / Screen to UVC Webcam"
    if ! is_function_linked "${FUNC_NAME}"; then
        start
    fi

    if ! is_stream_running; then
        local daemon_bin="${LIB_DIR}/uvc_daemon"
        local vdev
        vdev=$(detect_uvc_video_dev)
        sudo sh -c "\"${daemon_bin}\" \"${vdev}\" >/tmp/uvc_daemon.log 2>&1 &"
        echo $! > "${PID_STREAM}"
        sleep 0.5
    fi

    sudo pkill -f "raw_sink.py" 2>/dev/null || true
    sudo pkill -f "screenrecord" 2>/dev/null || true

    log_info "Piping live camera preview into shared frame buffer..."
    if [[ -x /mnt/dm1/system/bin/screenrecord ]]; then
        sudo nohup sh -c "/mnt/dm1/system/bin/screenrecord --output-format=h264 --size 640x360 - 2>/dev/null | ffmpeg -hide_banner -loglevel error -f h264 -i - -vcodec rawvideo -pix_fmt yuyv422 -s 640x360 -f rawvideo - | python3 ${LIB_DIR}/raw_sink.py" >/tmp/uvc_camera_feed.log 2>&1 &
    else
        sudo nohup sh -c "ffmpeg -hide_banner -loglevel error -re -f lavfi -i 'testsrc=size=640x360:rate=30' -vcodec rawvideo -pix_fmt yuyv422 -s 640x360 -f rawvideo - | python3 ${LIB_DIR}/raw_sink.py" >/tmp/uvc_camera_feed.log 2>&1 &
    fi
    log_success "Live Camera / Screen feed ACTIVE! Open the Camera app on your phone to stream live video."
}

stream_custom_file() {
    local vfile="$1"
    if [[ ! -f "$vfile" ]]; then
        log_error "Video file '$vfile' not found!"
        return 1
    fi
    if ! is_function_linked "${FUNC_NAME}"; then
        start
    fi
    if ! is_stream_running; then
        local daemon_bin="${LIB_DIR}/uvc_daemon"
        local vdev
        vdev=$(detect_uvc_video_dev)
        sudo nohup "${daemon_bin}" "${vdev}" >/tmp/uvc_daemon.log 2>&1 &
        echo $! > "${PID_STREAM}"
        sleep 0.5
    fi

    sudo pkill -f "raw_sink.py" 2>/dev/null || true
    log_info "Streaming '$vfile' in 640x360 loop mode to shared frame buffer..."
    sudo nohup sh -c "ffmpeg -hide_banner -loglevel error -re -stream_loop -1 -i '${vfile}' -vcodec rawvideo -pix_fmt yuyv422 -s 640x360 -f rawvideo - | python3 ${LIB_DIR}/raw_sink.py" >/tmp/uvc_video_feed.log 2>&1 &
    log_success "Custom video stream active over UVC Webcam."
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
    if is_stream_running; then
        local pids
        pids=$(sudo pgrep -d',' -f "uvc_daemon")
        if sudo pgrep -f "raw_sink.py" >/dev/null 2>&1; then
            stream_status="Live Video/Camera Stream (Daemon PID ${pids})"
        else
            stream_status="SMPTE Test Pattern (Daemon PID ${pids})"
        fi
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
        echo " 3) Stream SMPTE Test Pattern"
        echo " 4) Stream Live Phone Camera / Screen"
        echo " 5) Stream Custom Video File"
        echo " 6) Stop Active Video Feed"
        echo " 0) Back to Main Menu"
        echo
        read -rp "Choice: " choice
        case "$choice" in
            1) start; press_enter ;;
            2) stop; press_enter ;;
            3) stream_test_pattern; press_enter ;;
            4) stream_camera; press_enter ;;
            5)
                read -rp "Enter video file path (mp4/mkv/avi): " vpath
                if [[ -n "$vpath" ]]; then
                    stream_custom_file "$vpath"
                fi
                press_enter ;;
            6) stop_stream; log_success "Stream stopped."; press_enter ;;
            0) break ;;
            *) c_red "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    test)    stream_test_pattern ;;
    camera)  stream_camera ;;
    stream)  stream_camera ;;
    file)    stream_custom_file "${2:-}" ;;
    menu|"") menu ;;
    *) echo "Usage: $0 {start|stop|status|camera|test|file <path>|menu}" ;;
esac
