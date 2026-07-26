#!/bin/sh

CACHE_FILE="/tmp/sketchybar_mic_inputs.txt"
CURRENT_CACHE="/tmp/sketchybar_mic_current.txt"
VOLUME_CACHE="/tmp/sketchybar_mic_volume.txt"
MUTED_FLAG="/tmp/sketchybar_mic_muted"

fetch_devices() {
    SwitchAudioSource -a -t input 2>/dev/null > "$CACHE_FILE.tmp"
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    SwitchAudioSource -c -t input 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

restore_volume() {
    if [ -f "$VOLUME_CACHE" ]; then
        SAVED=$(cat "$VOLUME_CACHE")
        osascript -e "set volume input volume $SAVED" 2>/dev/null
        rm -f "$MUTED_FLAG"
    fi
}

mute_mic() {
    CURRENT_VOL=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)
    if [ "$CURRENT_VOL" != "0" ]; then
        echo "$CURRENT_VOL" > "$VOLUME_CACHE"
    fi
    osascript -e 'set volume input volume 0' 2>/dev/null
    touch "$MUTED_FLAG"
}

populate_popup() {
    for i in $(seq 0 19); do
        sketchybar --set "mic_input_$i" drawing=off 2>/dev/null
    done

    i=0

    CURRENT_IN=""
    [ -f "$CURRENT_CACHE" ] && CURRENT_IN=$(cat "$CURRENT_CACHE")

    if [ ! -f "$CACHE_FILE" ]; then
        sketchybar --set "mic_input_$i" drawing=on label="Loading..."
        return
    fi

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        sketchybar --set "mic_input_$i" drawing=on \
            label="$line" \
            click_script="SwitchAudioSource -s '$line' -t input 2>/dev/null; echo '$line' > '$CURRENT_CACHE'; sketchybar --set mic_input popup.drawing=off; SHORT=\$(echo '$line' | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/'); sketchybar --set mic_input label=\"\$SHORT\"; (cd '$CONFIG_DIR/plugins' && SENDER=refresh NAME=mic_input ./mic_input.sh) &"
        i=$((i + 1))
    done < "$CACHE_FILE"
}

# Handle internal commands (mute/unmute/refresh)
if [ "$SENDER" = "mute" ]; then
    mute_mic
    sketchybar --set mic_input label="Mic Off" icon.color=0xffcc4b4b
    exit 0
fi

if [ "$SENDER" = "unmute" ]; then
    restore_volume
    CURRENT_IN=$(cat "$CURRENT_CACHE" 2>/dev/null)
    SHORT=$(echo "$CURRENT_IN" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/')
    sketchybar --set mic_input label="$SHORT" icon.color=0xffeeeeee
    exit 0
fi

if [ "$SENDER" = "refresh" ]; then
    fetch_devices
    MUTED=""
    [ -f "$MUTED_FLAG" ] && MUTED="1"
    if [ "$MUTED" = "1" ]; then
        sketchybar --set mic_input label="Mic Off" icon.color=0xffcc4b4b
    else
        CURRENT_IN=$(cat "$CURRENT_CACHE" 2>/dev/null)
        SHORT=$(echo "$CURRENT_IN" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/')
        sketchybar --set mic_input label="$SHORT" icon.color=0xffeeeeee
    fi
    exit 0
fi

if [ "$SENDER" = "mouse.entered" ]; then
    case "$NAME" in
        mic_input_[0-9]*) echo "1" > /tmp/sketchybar_mic_hover; exit 0 ;;
    esac
    echo "1" > /tmp/sketchybar_mic_hover
    sketchybar --set audio_output popup.drawing=off
    populate_popup
    sketchybar --set $NAME popup.drawing=on
    ( fetch_devices; POPUP=$(sketchybar --query mic_input 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]'); if [ "$POPUP" = "1" ]; then populate_popup; fi ) &
    exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
    case "$NAME" in
        mic_input_[0-9]*) echo "0" > /tmp/sketchybar_mic_hover; ( sleep 1; HOVER=$(cat /tmp/sketchybar_mic_hover 2>/dev/null); if [ "$HOVER" != "1" ]; then sketchybar --set mic_input popup.drawing=off; fi ) & exit 0 ;;
    esac
    echo "0" > /tmp/sketchybar_mic_hover
    (
        sleep 1
        HOVER=$(cat /tmp/sketchybar_mic_hover 2>/dev/null)
        if [ "$HOVER" != "1" ]; then
            sketchybar --set $NAME popup.drawing=off
        fi
    ) &
    exit 0
fi

# Routine / init
MUTED=""
[ -f "$MUTED_FLAG" ] && MUTED="1"

if [ "$MUTED" = "1" ]; then
    sketchybar --set $NAME label="Mic Off" icon.color=0xffcc4b4b
else
    CURRENT_IN=""
    [ -f "$CURRENT_CACHE" ] && CURRENT_IN=$(cat "$CURRENT_CACHE")
    if [ -z "$CURRENT_IN" ]; then
        CURRENT_IN=$(SwitchAudioSource -c -t input 2>/dev/null)
        echo "$CURRENT_IN" > "$CURRENT_CACHE"
    fi
    if [ -n "$CURRENT_IN" ]; then
        SHORT=$(echo "$CURRENT_IN" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/')
        sketchybar --set $NAME label="$SHORT" icon.color=0xffeeeeee
    else
        sketchybar --set $NAME label="Mic" icon.color=0xffeeeeee
    fi
fi

# Background refresh
(fetch_devices) &