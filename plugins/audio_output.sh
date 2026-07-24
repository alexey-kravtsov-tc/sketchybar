#!/bin/sh

CACHE_FILE="/tmp/sketchybar_audio_outputs.txt"
CURRENT_CACHE="/tmp/sketchybar_audio_current.txt"

fetch_devices() {
    SwitchAudioSource -a -t output 2>/dev/null > "$CACHE_FILE.tmp"
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    SwitchAudioSource -c 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

# Background refresh: always fetch latest devices but don't block UI
refresh_in_background() {
    (fetch_devices) &
}

# Populate popup from cached list
populate_popup() {
    for i in $(seq 0 19); do
        sketchybar --set "audio_output_$i" drawing=off 2>/dev/null
    done

    CURRENT_OUT=""
    [ -f "$CURRENT_CACHE" ] && CURRENT_OUT=$(cat "$CURRENT_CACHE")

    if [ ! -f "$CACHE_FILE" ]; then
        sketchybar --set "audio_output_0" drawing=on label="Loading..."
        return
    fi

    i=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$line" = "$CURRENT_OUT" ]; then
            PREFIX="> "
        else
            PREFIX=""
        fi
        sketchybar --set "audio_output_$i" drawing=on \
            label="${PREFIX}${line}" \
            click_script="SwitchAudioSource -s '$line' 2>/dev/null; sketchybar --set audio_output popup.drawing=off; CURRENT=\$(SwitchAudioSource -c 2>/dev/null); SHORT=\$(echo \"\$CURRENT\" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/'); sketchybar --set audio_output label=\"\$SHORT\"; \$CONFIG_DIR/plugins/audio_output.sh refresh"
        i=$((i + 1))
    done < "$CACHE_FILE"
}

if [ "$1" = "refresh" ]; then
    fetch_devices
    CURRENT_OUT=$(cat "$CURRENT_CACHE" 2>/dev/null)
    SHORT=$(echo "$CURRENT_OUT" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/')
    sketchybar --set audio_output label="$SHORT"
    exit 0
fi

if [ "$SENDER" = "mouse.clicked" ]; then
    # Toggle popup
    CURRENT=$(sketchybar --query $NAME 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]')
    if [ "$CURRENT" = "1" ]; then
        sketchybar --set $NAME popup.drawing=off
        exit 0
    fi

    # Show cached list immediately
    populate_popup
    sketchybar --set $NAME popup.drawing=on

    # Refresh in background, then re-populate if popup is still open
    (
        fetch_devices
        POPUP=$(sketchybar --query audio_output 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]')
        if [ "$POPUP" = "1" ]; then
            populate_popup
        fi
    ) &
    exit 0
fi

# Routine / init: show current device, trigger background refresh
CURRENT_OUT=""
[ -f "$CURRENT_CACHE" ] && CURRENT_OUT=$(cat "$CURRENT_CACHE")
if [ -z "$CURRENT_OUT" ]; then
    CURRENT_OUT=$(SwitchAudioSource -c 2>/dev/null)
    echo "$CURRENT_OUT" > "$CURRENT_CACHE"
fi

if [ -n "$CURRENT_OUT" ]; then
    SHORT=$(echo "$CURRENT_OUT" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/')
    sketchybar --set $NAME label="$SHORT"
else
    sketchybar --set $NAME label="Audio"
fi

refresh_in_background