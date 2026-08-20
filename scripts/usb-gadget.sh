#!/usr/bin/env bash
#
# usb-gadget.sh - rooted Android HID controller
# Requires ConfigFS gadget: /config/usb_gadget/g1 (UDC: a600000.dwc3)
#
# Modularized with lib/hid_keymap.sh and lib/hid_touch.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

# Source modular keymap and digitizer libraries
source "${LIB_DIR}/hid_keymap.sh"
source "${LIB_DIR}/hid_touch.sh"

G=/config/usb_gadget/g1
C=$G/configs/b.1
F=$G/functions
UDC=a600000.dwc3
STATE=/tmp/usb-gadget.state
JIG_PID=/tmp/usb-gadget-jig.pid

KEYDEV=
TOUCHDEV=
MOUSEDEV=
MEDIADEV=

TYPE_DELAY_US=20000

die(){ echo "ERROR: $*" >&2; exit 1; }
need_root(){ [ "$(id -u)" = 0 ] || die "run as root (or with sudo)"; }
have(){ command -v "$1" >/dev/null 2>&1; }

sleep_us(){
    awk "BEGIN { printf \"%.6f\n\", ($1)/1000000 }" | {
        read -r s
        sleep "$s"
    }
}

hex8(){
    local n=$1
    [ "$n" -lt 0 ] && n=$((256+n))
    printf "%02x" $((n & 255))
}

map_one(){
    local func=$1
    local outvar=$2
    local d minor
    [ -r "$F/$func/dev" ] || return 1
    d=$(cat "$F/$func/dev") || return 1
    minor=${d#*:}
    [ -c "/dev/hidg$minor" ] || return 1
    eval "$outvar=/dev/hidg$minor"
}

map_hid(){
    KEYDEV=; TOUCHDEV=; MOUSEDEV=; MEDIADEV=
    map_one hid.keyboard KEYDEV || die "keyboard HID node unavailable"
    map_one hid.touchpad TOUCHDEV || die "touchpad HID node unavailable"
    [ -d "$F/hid.mouse" ] && map_one hid.mouse MOUSEDEV
    [ -d "$F/hid.consumer" ] && map_one hid.consumer MEDIADEV
}

link_if_missing(){
    local name=$1
    [ -L "$C/$name" ] || ln -s "$F/$name" "$C/$name" || die "cannot link $name"
}

setup_extra_functions(){
    # Standard 5-byte relative mouse if kernel allows dynamic creation
    if [ ! -d "$F/hid.mouse" ]; then
        if mkdir "$F/hid.mouse" 2>/dev/null; then
            echo 0 > "$F/hid.mouse/protocol"
            echo 1 > "$F/hid.mouse/subclass"
            echo 5 > "$F/hid.mouse/report_length"
            printf "\x05\x01\x09\x02\xa1\x01\x09\x01\xa1\x00\x05\x09\x19\x01\x29\x03\x15\x00\x25\x01\x95\x03\x75\x01\x81\x02\x95\x01\x75\x05\x81\x03\x05\x01\x09\x30\x09\x31\x09\x38\x09\x48\x15\x81\x25\x7f\x75\x08\x95\x04\x81\x06\xc0\xc0" > "$F/hid.mouse/report_desc" 2>/dev/null || true
            echo mouse >> "$STATE"
        fi
    fi

    # Generic Consumer Control if kernel allows dynamic creation
    if [ ! -d "$F/hid.consumer" ]; then
        if mkdir "$F/hid.consumer" 2>/dev/null; then
            echo 0 > "$F/hid.consumer/protocol"
            echo 0 > "$F/hid.consumer/subclass"
            echo 2 > "$F/hid.consumer/report_length"
            printf "\x05\x0c\x09\x01\xa1\x01\x15\x00\x26\xff\x03\x19\x00\x2a\xff\x03\x75\x10\x95\x01\x81\x00\xc0" > "$F/hid.consumer/report_desc" 2>/dev/null || true
            echo consumer >> "$STATE"
        fi
    fi
}

start(){
    need_root
    [ -d "$G" ] || die "$G missing"
    [ -d "$C" ] || die "$C missing"
    : > "$STATE"
    echo none > "$G/UDC" 2>/dev/null || true
    link_if_missing hid.keyboard
    link_if_missing hid.touchpad
    setup_extra_functions
    [ -d "$F/hid.mouse" ] && link_if_missing hid.mouse
    [ -d "$F/hid.consumer" ] && link_if_missing hid.consumer
    echo "$UDC" > "$G/UDC" || die "UDC bind failed"
    sleep 1
    map_hid
    echo "HID READY"
    echo "  keyboard : $KEYDEV"
    echo "  touchpad : $TOUCHDEV"
    echo "  mouse    : ${MOUSEDEV:-using touchpad relative mode}"
    echo "  consumer : ${MEDIADEV:-unavailable}"
    echo "  UDC      : $(cat "$G/UDC" 2>/dev/null)"
}

stop(){
    need_root
    jiggle_stop 2>/dev/null
    echo none > "$G/UDC" 2>/dev/null || true
    rm -f "$C/hid.keyboard" "$C/hid.touchpad" "$C/hid.mouse" "$C/hid.consumer"
    if grep -qx mouse "$STATE" 2>/dev/null; then
        rmdir "$F/hid.mouse" 2>/dev/null || true
    fi
    if grep -qx consumer "$STATE" 2>/dev/null; then
        rmdir "$F/hid.consumer" 2>/dev/null || true
    fi
    rm -f "$STATE"
    echo "HID unbound and HID links removed."
}

status(){
    echo "=== USB ==="
    echo "controller: $(getprop sys.usb.controller 2>/dev/null || echo "$UDC")"
    echo "config:     $(getprop sys.usb.config 2>/dev/null || echo "custom")"
    echo "UDC:        $(cat "$G/UDC" 2>/dev/null)"
    echo "state:      $(cat /sys/class/udc/$UDC/state 2>/dev/null || echo "unknown")"
    echo
    echo "=== FUNCTIONS ==="
    for f in "$F"/hid.*; do
        [ -d "$f" ] || continue
        echo "$(basename "$f"): $(cat "$f/dev" 2>/dev/null)"
    done
    echo
    echo "=== ACTIVE CONFIG LINKS ==="
    ls -l "$C"/hid.* 2>/dev/null || echo "none"
    echo
    echo "=== NODES ==="
    ls -l /dev/hidg* 2>/dev/null || echo "none"
}

# ---------- Keyboard Engine ----------

key_report(){
    local mod=${1:-00} code=${2:-00}
    printf "\x$mod\x00\x$code\x00\x00\x00\x00\x00" > "$KEYDEV"
}

key_send(){
    local code
    code=$(keycode "$1") || die "unknown key: $1"
    key_report 00 "$code"
    printf "\0\0\0\0\0\0\0\0" > "$KEYDEV"
}

hotkey_send(){
    local mod=0 m code
    shift
    [ "$#" -ge 2 ] || die "hotkey requires modifier(s) and key"
    while [ "$#" -gt 1 ]; do
        m=$(modcode "$1") || die "unknown modifier: $1"
        mod=$((mod | 16#$m))
        shift
    done
    code=$(keycode "$1") || die "unknown key: $1"
    printf "\x$(printf "%02x" "$mod")\x00\x$code\x00\x00\x00\x00\x00" > "$KEYDEV"
    printf "\0\0\0\0\0\0\0\0" > "$KEYDEV"
}

type_text(){
    local text="$1" delay="${2:-$TYPE_DELAY_US}" i ch p mod code
    [ -n "$text" ] || return
    i=1
    while [ "$i" -le "${#text}" ]; do
        ch=$(printf "%s" "$text" | cut -c "$i")
        p=$(char_map "$ch") || die "unsupported character: [$ch]"
        mod=${p%%:*}; code=${p##*:}
        key_report "$mod" "$code"
        printf "\0\0\0\0\0\0\0\0" > "$KEYDEV"
        sleep_us "$delay"
        i=$((i+1))
    done
}

preset(){
    case "$1" in
    windows-run) hotkey_send GUI R;;
    linux-terminal) hotkey_send CTRL ALT T;;
    mac-spotlight) hotkey_send GUI SPACE;;
    *) die "preset: windows-run | linux-terminal | mac-spotlight";;
    esac
}

# ---------- Touchpad Report ID 01: relative pointer ----------

ptr01(){
    local b=$1 x=$2 y=$3
    printf "\x01\x$(printf "%02x" "$b")\x$(hex8 "$x")\x$(hex8 "$y")\x00\x00\x00\x00\x00\x00\x00\x00" > "$TOUCHDEV"
}

move_touch(){
    local x=$1 y=$2
    while [ "$x" -gt 127 ]; do ptr01 0 127 0; x=$((x-127)); done
    while [ "$x" -lt -127 ]; do ptr01 0 -127 0; x=$((x+127)); done
    while [ "$y" -gt 127 ]; do ptr01 0 0 127; y=$((y-127)); done
    while [ "$y" -lt -127 ]; do ptr01 0 0 -127; y=$((y+127)); done
    [ "$x" -ne 0 ] || [ "$y" -ne 0 ] || return
    ptr01 0 "$x" "$y"
}

click_touch(){
    case "$1" in left) b=1;; right) b=2;; middle) b=4;; *) die "button: left|right|middle";; esac
    ptr01 "$b" 0 0
    ptr01 0 0 0
}

doubleclick_touch(){
    click_touch "$1"; sleep 0.08; click_touch "$1"
}

# ---------- Separate 5-byte mouse: buttons/X/Y/V/H wheel ----------

mouse_report(){
    local b=$1 x=$2 y=$3 v=$4 h=$5
    printf "\x$(printf "%02x" "$b")\x$(hex8 "$x")\x$(hex8 "$y")\x$(hex8 "$v")\x$(hex8 "$h")" > "$MOUSEDEV"
}

mouse_move(){
    if [ -n "$MOUSEDEV" ]; then
        mouse_report 0 "$1" "$2" 0 0
    else
        move_touch "$1" "$2"
    fi
}

mouse_click(){
    if [ -n "$MOUSEDEV" ]; then
        case "$1" in left) b=1;; right) b=2;; middle) b=4;; *) die "button: left|right|middle";; esac
        mouse_report "$b" 0 0 0 0
        mouse_report 0 0 0 0 0
    else
        click_touch "$1"
    fi
}

mouse_double(){
    mouse_click "$1"; sleep 0.08; mouse_click "$1"
}

mouse_drag(){
    local b=1 x=$1 y=$2 dx=$3 dy=$4
    if [ -n "$MOUSEDEV" ]; then
        mouse_report "$b" 0 0 0 0
        move_mouse_smooth "$dx" "$dy"
        mouse_report 0 0 0 0 0
    else
        ptr01 1 0 0
        move_touch "$dx" "$dy"
        ptr01 0 0 0
    fi
}

move_mouse_smooth(){
    local x=$1 y=$2
    if [ -n "$MOUSEDEV" ]; then
        while [ "$x" -gt 127 ]; do mouse_move 127 0; x=$((x-127)); done
        while [ "$x" -lt -127 ]; do mouse_move -127 0; x=$((x+127)); done
        while [ "$y" -gt 127 ]; do mouse_move 0 127; y=$((y-127)); done
        while [ "$y" -lt -127 ]; do mouse_move 0 -127; y=$((y+127)); done
        [ "$x" -ne 0 ] || [ "$y" -ne 0 ] || return
        mouse_move "$x" "$y"
    else
        move_touch "$x" "$y"
    fi
}

scroll(){
    if [ -n "$MOUSEDEV" ]; then
        mouse_report 0 0 0 "$1" "${2:-0}"
    else
        die "wheel scroll requires dedicated hid.mouse interface"
    fi
}

# ---------- Consumer/media ----------

media_code(){
    case "$1" in
    PLAY) echo 00b0;; PAUSE) echo 00b1;; PLAYPAUSE) echo 00cd;;
    NEXT|NEXTTRACK) echo 00b5;; PREV|PREVTRACK) echo 00b6;;
    MUTE) echo 00e2;; VOLUP) echo 00e9;; VOLDOWN) echo 00ea;;
    *) return 1;;
    esac
}

media(){
    [ -n "$MEDIADEV" ] || die "consumer HID unavailable"
    local c
    c=$(media_code "$1") || die "unknown media key: $1"
    printf "\x${c%??}\x${c#??}" > "$MEDIADEV"
    printf "\0\0" > "$MEDIADEV"
}

# ---------- Jiggler ----------

jiggle_start(){
    jiggle_stop 2>/dev/null
    local interval=${1:-30} radius=${2:-2}
    (
        while :; do
            move_mouse_smooth "$radius" 0
            move_mouse_smooth "-$radius" 0
            sleep "$interval"
        done
    ) &
    echo $! > "$JIG_PID"
    echo "jiggler PID $(cat "$JIG_PID")"
}

jiggle_stop(){
    [ -f "$JIG_PID" ] || return
    kill "$(cat "$JIG_PID")" 2>/dev/null || true
    rm -f "$JIG_PID"
    echo "jiggler stopped"
}

# ---------- DuckyScript ----------

run_ducky(){
    local file=$1 line cmd rest n i
    [ -f "$file" ] || die "payload not found: $file"

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf "%s" "$line" | sed "s/\r$//;s/^[[:space:]]*//")
        [ -n "$line" ] || continue

        case "$line" in
        REM|REM\ *) continue;;
        DELAY\ *)
            sleep_us $(( ${line#DELAY } * 1000 ))
            continue;;
        STRING\ *)
            type_text "${line#STRING }"
            continue;;
        REPEAT\ *)
            n=${line#REPEAT }
            continue;;
        esac

        set -- $line
        cmd=$1
        shift

        case "$cmd" in
        STRING)
            type_text "$*";;
        DELAY)
            sleep_us $(( $1 * 1000 ));;
        CTRL|ALT|SHIFT|GUI|WIN|CMD|META)
            hotkey_send "$cmd" "$@";;
        *)
            if keycode "$cmd" >/dev/null 2>&1; then
                key_send "$cmd"
            else
                hotkey_send "$cmd" "$@"
            fi
            ;;
        esac
    done < "$file"
}

# ---------- TUI ----------

tui(){
    while :; do
        clear 2>/dev/null || true
        cat << "EOF_TUI"
======================================
          USB HID CONTROL
======================================
1 Type text      2 Key        3 Hotkey
4 Preset Hotkey  5 Move       6 Click
7 Double click   8 Scroll     9 Touch tap
10 Touch drag   11 Media     12 DuckyScript
13 Jiggle start 14 Stop jig  15 Status
0 Exit
EOF_TUI
        printf "Choice: "; read -r c
        case "$c" in
        1) printf "Text: "; read -r t; type_text "$t";;
        2) printf "Key: "; read -r k; key_send "$k";;
        3) printf "Hotkey: "; read -r h; set -- $h; hotkey_send "$@";;
        4) printf "Preset: "; read -r p; preset "$p";;
        5) printf "DX DY: "; read -r x y; move_mouse_smooth "$x" "$y";;
        6) printf "Button: "; read -r b; mouse_click "$b";;
        7) printf "Button: "; read -r b; mouse_double "$b";;
        8) printf "V H: "; read -r v h; scroll "$v" "$h";;
        9) printf "X Y: "; read -r x y; tap "$x" "$y";;
        10) printf "X1 Y1 X2 Y2: "; read -r a b c d; drag_touch "$a" "$b" "$c" "$d";;
        11) printf "Media: "; read -r m; media "$m";;
        12) printf "File: "; read -r f; run_ducky "$f";;
        13) jiggle_start;;
        14) jiggle_stop;;
        15) status; printf "Press Enter..."; read -r _;;
        0) return;;
        esac
    done
}

need_root
case "$1" in
start) start;;
stop) stop;;
restart) stop; sleep 1; start;;
status) status;;
map) map_hid; echo "keyboard=$KEYDEV"; echo "touchpad=$TOUCHDEV"; echo "mouse=$MOUSEDEV"; echo "consumer=$MEDIADEV";;
key) map_hid; key_send "$2";;
hotkey) map_hid; shift; hotkey_send "$@";;
preset) map_hid; preset "$2";;
type) map_hid; type_text "$2" "${3:-$TYPE_DELAY_US}";;
move) map_hid; move_mouse_smooth "$2" "$3";;
click) map_hid; mouse_click "$2";;
doubleclick) map_hid; mouse_double "$2";;
drag) map_hid; mouse_drag "$2" "$3" "$4" "$5";;
scroll) map_hid; scroll "$2" "${3:-0}";;
absolute) map_hid; touch_down "$2" "$3";;
tap) map_hid; tap "$2" "$3";;
touch-down) map_hid; touch_down "$2" "$3";;
touch-up) map_hid; touch_up "$2" "$3";;
drag-touch) map_hid; drag_touch "$2" "$3" "$4" "$5" "${6:-30}";;
screen-tap)
    map_hid
    set -- $(absolute_from_screen "$2" "$3" "$4" "$5")
    tap "$1" "$2";;
media) map_hid; media "$2";;
jiggle) map_hid; jiggle_start "${2:-30}" "${3:-2}";;
jiggle-stop) jiggle_stop;;
ducky) map_hid; run_ducky "$2";;
tui) map_hid; tui;;
*)
cat <<EOF
usb-gadget.sh

Lifecycle:
  start | stop | restart | status | map

Keyboard:
  key KEY
  type TEXT [delay-us]
  hotkey MOD... KEY
  preset windows-run|linux-terminal|mac-spotlight

Pointer:
  move DX DY
  click left|right|middle
  doubleclick BUTTON
  drag X Y DX DY

Wheel:
  scroll VERTICAL [HORIZONTAL]

Touch:
  absolute X Y
  tap X Y
  touch-down X Y
  touch-up X Y
  drag-touch X1 Y1 X2 Y2 [steps]
  screen-tap X Y WIDTH HEIGHT

Media:
  media PLAY|PAUSE|PLAYPAUSE|NEXT|PREV|MUTE|VOLUP|VOLDOWN

Automation:
  jiggle [interval] [radius]
  jiggle-stop
  ducky FILE

Interface:
  tui
EOF
;;
esac
