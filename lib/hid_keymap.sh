#!/usr/bin/env bash
#
# hard-tools: lib/hid_keymap.sh
# USB HID 104-Key Keycodes, Modifiers, and ASCII Character Map
#

keycode(){
    case "$1" in
    A|a) echo 04;; B|b) echo 05;; C|c) echo 06;; D|d) echo 07;;
    E|e) echo 08;; F|f) echo 09;; G|g) echo 0a;; H|h) echo 0b;;
    I|i) echo 0c;; J|j) echo 0d;; K|k) echo 0e;; L|l) echo 0f;;
    M|m) echo 10;; N|n) echo 11;; O|o) echo 12;; P|p) echo 13;;
    Q|q) echo 14;; R|r) echo 15;; S|s) echo 16;; T|t) echo 17;;
    U|u) echo 18;; V|v) echo 19;; W|w) echo 1a;; X|x) echo 1b;;
    Y|y) echo 1c;; Z|z) echo 1d;;
    1) echo 1e;; 2) echo 1f;; 3) echo 20;; 4) echo 21;; 5) echo 22;;
    6) echo 23;; 7) echo 24;; 8) echo 25;; 9) echo 26;; 0) echo 27;;
    ENTER|RETURN) echo 28;; ESC|ESCAPE) echo 29;; BACKSPACE|BACK) echo 2a;;
    TAB) echo 2b;; SPACE) echo 2c;; MINUS) echo 2d;; EQUAL|PLUS) echo 2e;;
    LEFTBRACE) echo 2f;; RIGHTBRACE) echo 30;; BACKSLASH) echo 31;;
    SEMICOLON) echo 33;; APOSTROPHE) echo 34;; GRAVE) echo 35;;
    COMMA) echo 36;; DOT|PERIOD) echo 37;; SLASH) echo 38;;
    CAPSLOCK) echo 39;;
    F1) echo 3a;; F2) echo 3b;; F3) echo 3c;; F4) echo 3d;;
    F5) echo 3e;; F6) echo 3f;; F7) echo 40;; F8) echo 41;;
    F9) echo 42;; F10) echo 43;; F11) echo 44;; F12) echo 45;;
    PRINTSCREEN) echo 46;; SCROLLLOCK) echo 47;; PAUSE) echo 48;;
    INSERT) echo 49;; HOME) echo 4a;; PAGEUP|PGUP) echo 4b;;
    DELETE|DEL) echo 4c;; END) echo 4d;; PAGEDOWN|PGDN) echo 4e;;
    RIGHT) echo 4f;; LEFT) echo 50;; DOWN) echo 51;; UP) echo 52;;
    NUMLOCK) echo 53;;
    *) return 1;;
    esac
}

modcode(){
    case "$1" in
    CTRL|CONTROL) echo 01;;
    SHIFT) echo 02;;
    ALT) echo 04;;
    GUI|WIN|CMD|META) echo 08;;
    *) return 1;;
    esac
}

char_map(){
    case "$1" in
    [a-z]) echo "00:$(keycode "$1")";;
    [A-Z]) echo "02:$(keycode "$1")";;
    ' ') echo 00:2c;; $'\n') echo 00:28;; $'\t') echo 00:2b;;
    '!') echo 02:1e;; '@') echo 02:1f;; '#') echo 02:20;; '$') echo 02:21;;
    '%') echo 02:22;; '^') echo 02:23;; '&') echo 02:24;; '*') echo 02:25;;
    '(') echo 02:26;; ')') echo 02:27;;
    '-') echo 00:2d;; '_') echo 02:2d;; '=') echo 00:2e;; '+') echo 02:2e;;
    '[') echo 00:2f;; '{') echo 02:2f;; ']') echo 00:30;; '}') echo 02:30;;
    '\\') echo 00:31;; '|') echo 02:31;;
    ';') echo 00:33;; ':') echo 02:33;; "'") echo 00:34;; '"') echo 02:34;;
    '`') echo 00:35;; '~') echo 02:35;;
    ',') echo 00:36;; '<') echo 02:36;; '.') echo 00:37;; '>') echo 02:37;;
    '/') echo 00:38;; '?') echo 02:38;;
    *) return 1;;
    esac
}
