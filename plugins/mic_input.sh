#!/bin/sh

# Merged mic level + mic input source control.
#
# State 1 (default): bar shows text "{mic level}% << {input source}".
# State 2 (after click on text): text item's label blanked, mic_slider
#                   visible next to it, popup lists available input
#                   devices with the current one marked ( bold ).
#                   Auto-collapses after HOLD_SECONDS of pointer leaving.
#
# Symmetric to the merged volume control.

EXPANDED_WIDTH=200
HOLD_SECONDS=5

ITEM="mic"
SLIDER="mic_slider"
POPUP_PREFIX="mic_input"

HOVER_FLAG="/tmp/sketchybar_mic_hover"
TIMER_TAG="SKETCHYBAR_MIC_TIMER"

. "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/_hover.sh"

DEVICES_CACHE="/tmp/sketchybar_mic_inputs.txt"
CURRENT_CACHE="/tmp/sketchybar_mic_current.txt"

short_name() {
    echo "$1" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/'
}

# --- Source helpers ----------------------------------------------------

# Single-instance tag for the background fetch (avoids overlapping
# SwitchAudioSource processes on rapid routine ticks).
FETCH_TAG="SKETCHYBAR_MIC_FETCH"

fetch_devices() {
    SwitchAudioSource -a -t input 2>/dev/null > "$DEVICES_CACHE.tmp"
    mv "$DEVICES_CACHE.tmp" "$DEVICES_CACHE"
    SwitchAudioSource -c -t input 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

refresh_in_background() {
    pkill -f "$FETCH_TAG" 2>/dev/null
    (
        exec -a "$FETCH_TAG" sh -c '
            "'"$CONFIG_DIR"'"/plugins/mic_input.sh __fetch
        '
    ) 2>/dev/null &
    disown 2>/dev/null
}

# Hidden entry-point invoked by the background fetch.
if [ "$1" = "__fetch" ]; then
    fetch_devices
    exit 0
fi

current_input() {
    [ -f "$CURRENT_CACHE" ] && cat "$CURRENT_CACHE" && return
    SwitchAudioSource -c -t input 2>/dev/null
}

# --- Bar helpers -------------------------------------------------------

get_mic_level() {
    osascript -e 'input volume of (get volume settings)' 2>/dev/null
}

# Render State 1 label.
render_idle_label() {
    IN=$(current_input)
    SHORT=$(short_name "$IN")
    [ -z "$SHORT" ] && SHORT="Mic"
    MIC=$(get_mic_level)
    sketchybar --set "$ITEM" \
        label="${MIC}% / ${SHORT}" \
        label.drawing=on \
        popup.drawing=off
    sketchybar --set "$SLIDER" drawing=off
}

# Show State 2.
expand() {
    echo "1" > "$HOVER_FLAG"
    kill_timer

    sketchybar --set "$ITEM" label="" label.drawing=off popup.drawing=on
    sketchybar --set "$SLIDER" drawing=on slider.width="$EXPANDED_WIDTH"

    populate_popup
}

# Restore State 1.
collapse() {
    echo "0" > "$HOVER_FLAG"
    sketchybar --set "$SLIDER" drawing=off
    sketchybar --set "$ITEM" popup.drawing=off
    render_idle_label
}

# Fill popup rows, marking the current one with  + bold.
populate_popup() {
    for i in $(seq 0 19); do
        sketchybar --set "${POPUP_PREFIX}_$i" drawing=off 2>/dev/null
    done

    if [ ! -f "$DEVICES_CACHE" ]; then
        sketchybar --set "${POPUP_PREFIX}_0" drawing=on \
            icon="·" \
            label.font="Hack Nerd Font:Regular:12.0" \
            label="Loading..."
        return
    fi

    CUR=$(current_input)
    i=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$line" = "$CUR" ]; then
            ICON="●"
            FONT="Hack Nerd Font:Bold:13.0"
        else
            ICON="·"
            FONT="Hack Nerd Font:Regular:12.0"
        fi
        sketchybar --set "${POPUP_PREFIX}_$i" drawing=on \
            icon="$ICON" \
            icon.font="Hack Nerd Font:Bold:14.0" \
            label.font="$FONT" \
            label="$line" \
            click_script="SwitchAudioSource -s '$line' -t input 2>/dev/null; \$CONFIG_DIR/plugins/mic_input.sh switch"
        i=$((i + 1))
    done < "$DEVICES_CACHE"
}

# --- Timer helpers -----------------------------------------------------
#
# Single-instance collapse timer using pkill -f so concurrent mouse.exited
# events cannot pile up children. See comments in plugins/volume.sh.

kill_timer() {
    pkill -f "$TIMER_TAG" 2>/dev/null
}

start_timer() {
    kill_timer
    (
        exec -a "$TIMER_TAG" sh -c '
            sleep '"$HOLD_SECONDS"'
            if [ "$(cat '"$HOVER_FLAG"' 2>/dev/null)" = "1" ]; then exit 0; fi
            '"$CONFIG_DIR"'/plugins/mic_input.sh __collapse
        '
    ) 2>/dev/null &
    disown 2>/dev/null
}

# Background-only entry point invoked by the collapse timer.
if [ "$1" = "__collapse" ]; then
    collapse
    exit 0
fi

# --- Entry points ------------------------------------------------------

# Called from a popup row's click_script after picking a device.
if [ "$1" = "switch" ]; then
    # Give CoreAudio a moment to register the newly-selected device.
    sleep 0.3
    fetch_devices
    POPUP_ON=$(sketchybar --query "$ITEM" 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]')
    if [ "$POPUP_ON" = "1" ]; then
        populate_popup
    else
        render_idle_label
    fi
    exit 0
fi

# Init (SENDER=forced on first run) or routine refresh (SENDER=routine).
if [ -z "$SENDER" ] || [ "$SENDER" = "forced" ] || [ "$SENDER" = "routine" ]; then
    [ ! -f "$DEVICES_CACHE" ] && refresh_in_background
    render_idle_label
    MIC=$(get_mic_level)
    sketchybar --set "$SLIDER" slider.percentage="$MIC"
    exit 0
fi

# --- Mouse events ------------------------------------------------------

# Invert a popup row's colors (hover effect).
hover_row_on() {
    sketchybar --set "$1" \
        background.drawing=on \
        background.color=0xffeeeeee \
        background.corner_radius=4 \
        background.height=18 \
        label.color=0xff222222 \
        icon.color=0xff222222
}

# Restore a popup row's default colors.
hover_row_off() {
    sketchybar --set "$1" \
        background.drawing=off \
        label.color=0xffeeeeee \
        icon.color=0xffffffff
}

if [ "$SENDER" = "mouse.entered" ]; then
    case "$NAME" in
        ${POPUP_PREFIX}_[0-9]*) echo "1" > "$HOVER_FLAG"; kill_timer; hover_row_on "$NAME"; exit 0 ;;
    esac
    echo "1" > "$HOVER_FLAG"
    kill_timer
    [ "$NAME" = "$ITEM" ] && apply_hover_on "$NAME"
    exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
    case "$NAME" in
        ${POPUP_PREFIX}_[0-9]*)
            echo "0" > "$HOVER_FLAG"
            hover_row_off "$NAME"
            start_timer
            exit 0 ;;
    esac
    echo "0" > "$HOVER_FLAG"
    [ "$NAME" = "$ITEM" ] && apply_hover_off "$NAME"
    start_timer
    exit 0
fi

if [ "$SENDER" = "mouse.clicked" ]; then
    # Slider drag -> set mic input volume.
    if [ "$NAME" = "$SLIDER" ] && [ -n "$PERCENTAGE" ]; then
        osascript -e "set volume input volume $PERCENTAGE"
        sketchybar --set "$SLIDER" slider.percentage="$PERCENTAGE"
        start_timer
        exit 0
    fi

    # Click the text item -> toggle State 2.
    if [ "$NAME" = "$ITEM" ]; then
        SLIDER_DRAWN=$(sketchybar --query "$SLIDER" 2>/dev/null | grep -m1 -o '"drawing" : [a-z]*' | grep -o 'on\|off')
        if [ "$SLIDER_DRAWN" = "on" ]; then
            collapse
        else
            expand
            start_timer
        fi
        exit 0
    fi
fi
