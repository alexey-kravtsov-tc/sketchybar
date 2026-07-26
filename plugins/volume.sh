#!/bin/sh

# Merged volume + audio output control.
#
# State 1 (default): bar shows text "  {output} >> {volume}%"  (popup hidden,
#                   slider hidden).
# State 2 (after click on text item): text item's label is blanked, the
#                   volume_slider next to it becomes visible, and the popup
#                   lists available output devices with the current one
#                   marked (● + bold). Collapses back to State 1 after
#                   HOLD_SECONDS of the pointer leaving the whole control.

EXPANDED_WIDTH=200
HOLD_SECONDS=5

ITEM="volume"
SLIDER="volume_slider"
POPUP_PREFIX="volume_output"

HOVER_FLAG="/tmp/sketchybar_volume_hover"
TIMER_PID="/tmp/sketchybar_volume_timer_pid"

DEVICES_CACHE="/tmp/sketchybar_volume_devices.txt"
CURRENT_CACHE="/tmp/sketchybar_volume_current.txt"

# Shorten long device names for the bar label.
short_name() {
    echo "$1" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/'
}

# --- Audio source helpers ------------------------------------------------

fetch_devices() {
    SwitchAudioSource -a -t output 2>/dev/null > "$DEVICES_CACHE.tmp"
    mv "$DEVICES_CACHE.tmp" "$DEVICES_CACHE"
    SwitchAudioSource -c 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

refresh_in_background() { ( fetch_devices ) & }

current_output() {
    [ -f "$CURRENT_CACHE" ] && cat "$CURRENT_CACHE" && return
    SwitchAudioSource -c 2>/dev/null
}

# --- Bar helpers ---------------------------------------------------------

get_volume() {
    if [ -n "$INFO" ]; then
        echo "$INFO"
    else
        osascript -e 'output volume of (get volume settings)' 2>/dev/null
    fi
}

# Render the State 1 text label using the current cached output + volume.
render_idle_label() {
    OUT=$(current_output)
    SHORT=$(short_name "$OUT")
    [ -z "$SHORT" ] && SHORT="Audio"
    VOL=$(get_volume)
    sketchybar --set "$ITEM" \
        label="${SHORT} >> ${VOL}%" \
        label.drawing=on \
        popup.drawing=off
    sketchybar --set "$SLIDER" drawing=off
}

# Show State 2: text item still drawn (as popup anchor) but its label
# blanked/padded to nothing, slider visible, popup populated and shown.
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

# Fill popup rows from cached devices, marking the current one with ● + bold.
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

    CUR=$(current_output)
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
            click_script="SwitchAudioSource -s '$line' 2>/dev/null; \$CONFIG_DIR/plugins/volume.sh switch"
        i=$((i + 1))
    done < "$DEVICES_CACHE"
}

# --- Timer helpers -------------------------------------------------------

kill_timer() {
    if [ -f "$TIMER_PID" ]; then
        OLD_PID=$(cat "$TIMER_PID" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            kill "$OLD_PID" 2>/dev/null
        fi
        rm -f "$TIMER_PID"
    fi
}

start_timer() {
    kill_timer
    (
        sleep "$HOLD_SECONDS"
        HOVER=$(cat "$HOVER_FLAG" 2>/dev/null)
        if [ "$HOVER" != "1" ]; then
            collapse
        fi
    ) &
    echo $! > "$TIMER_PID"
}

# --- Entry points --------------------------------------------------------

# Called from a popup row's click_script after the user picks a device.
if [ "$1" = "switch" ]; then
    # Give CoreAudio a moment to register the newly-selected device.
    sleep 0.3
    fetch_devices
    # Refresh current cached and re-render the idle label, but if the popup
    # is currently open (state 2), repopulate so the new current lights up.
    POPUP_ON=$(sketchybar --query "$ITEM" 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]')
    if [ "$POPUP_ON" = "1" ]; then
        populate_popup
    else
        render_idle_label
    fi
    exit 0
fi

# Volume change event or init/routine.
if [ "$SENDER" = "volume_change" ] || [ -z "$SENDER" ] \
   || [ "$SENDER" = "forced" ] || [ "$SENDER" = "routine" ]; then
    [ ! -f "$DEVICES_CACHE" ] && refresh_in_background
    render_idle_label
    VOL=$(get_volume)
    sketchybar --set "$SLIDER" slider.percentage="$VOL"
    exit 0
fi

# Routine refresh of device list (called periodically via update_freq).
if [ "$1" = "refresh_devices" ]; then
    refresh_in_background
    POPUP_ON=$(sketchybar --query "$ITEM" 2>/dev/null | grep -o '"popup" : {[^}]*}' | grep -o '"drawing" : [01]' | grep -o '[01]')
    if [ "$POPUP_ON" = "1" ]; then
        populate_popup
    else
        render_idle_label
    fi
    exit 0
fi

# --- Mouse events --------------------------------------------------------

if [ "$SENDER" = "mouse.entered" ]; then
    # Hovering any part of the control = stay open (cancel collapse timer).
    case "$NAME" in
        ${POPUP_PREFIX}_[0-9]*) echo "1" > "$HOVER_FLAG"; kill_timer; exit 0 ;;
    esac
    echo "1" > "$HOVER_FLAG"
    kill_timer
    exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
    case "$NAME" in
        ${POPUP_PREFIX}_[0-9]*)
            echo "0" > "$HOVER_FLAG"
            start_timer
            exit 0 ;;
    esac
    echo "0" > "$HOVER_FLAG"
    start_timer
    exit 0
fi

if [ "$SENDER" = "mouse.clicked" ]; then
    # Slider drag -> set system volume, keep expanded.
    if [ "$NAME" = "$SLIDER" ] && [ -n "$PERCENTAGE" ]; then
        osascript -e "set volume output volume $PERCENTAGE"
        sketchybar --set "$SLIDER" slider.percentage="$PERCENTAGE"
        start_timer
        exit 0
    fi

    # Clicking the text item toggles to State 2.
    if [ "$NAME" = "$ITEM" ]; then
        # If already expanded, treat click as a toggle back to State 1.
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
