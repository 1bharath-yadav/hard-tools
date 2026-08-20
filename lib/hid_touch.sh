#!/usr/bin/env bash
#
# hard-tools: lib/hid_touch.sh
# Precision Touchpad (Report ID 0x04) Digitizer Functions
#

TOUCH_DELAY=0.05
TOUCH_MAX=3528

touch04(){
    local flags=$1 x=$2 y=$3 scan=$4 contacts=$5 button=${6:-0}
    printf '%b' "\\x04\\x$(printf '%02x' "$flags")\
\\x$(printf '%02x' $((x & 255)))\\x$(printf '%02x' $(((x >> 8) & 255)))\
\\x$(printf '%02x' $((y & 255)))\\x$(printf '%02x' $(((y >> 8) & 255)))\
\\x$(printf '%02x' $((scan & 255)))\\x$(printf '%02x' $(((scan >> 8) & 255)))\
\\x$(printf '%02x' "$contacts")\\x$(printf '%02x' "$button")\\x00\\x00" > "$TOUCHDEV"
}

clamp_coord(){
    [ "$1" -lt 0 ] && echo 0 && return
    [ "$1" -gt "$TOUCH_MAX" ] && echo "$TOUCH_MAX" && return
    echo "$1"
}

touch_down(){
    local x y
    x=$(clamp_coord "$1"); y=$(clamp_coord "$2")
    touch04 03 "$x" "$y" 0 1 0
}

touch_up(){
    local x y
    x=$(clamp_coord "$1"); y=$(clamp_coord "$2")
    touch04 01 "$x" "$y" 0 0 0
}

tap(){
    touch_down "$1" "$2"
    sleep "$TOUCH_DELAY"
    touch_up "$1" "$2"
}

drag_touch(){
    local x1=$1 y1=$2 x2=$3 y2=$4 steps=${5:-30}
    local i x y dx dy
    touch_down "$x1" "$y1"
    dx=$((x2-x1)); dy=$((y2-y1))
    i=1
    while [ "$i" -le "$steps" ]; do
        x=$((x1 + dx*i/steps))
        y=$((y1 + dy*i/steps))
        touch04 03 "$(clamp_coord "$x")" "$(clamp_coord "$y")" "$i" 1 0
        sleep 0.01
        i=$((i+1))
    done
    touch_up "$x2" "$y2"
}

absolute_from_screen(){
    local sx=$1 sy=$2 sw=$3 sh=$4
    [ "$sw" -gt 0 ] && [ "$sh" -gt 0 ] || die "screen width/height required"
    echo $((sx*TOUCH_MAX/sw)) $((sy*TOUCH_MAX/sh))
}
