#!/bin/sh

# Merged volume + audio output control (click-only, synchronous).
#
# State 1 (default): bar shows text "{output} >> {volume}%" (popup hidden,
#                   slider hidden).
# State 2 (after click on text item): the slider appears NEXT TO the text
#                   label (label stays visible) and the popup lists available
#                   output devices with the current one marked (● + bold).
# State 2 stays open until:
#   - the text item is clicked again (toggle back to State 1), OR
#   - a device row is clicked (switch device, then collapse to State 1).
# Dragging the slider updates the system volume and keeps State 2 open.
# No timers, no hover, no auto-dismiss.
#
# Delivery model (matches sketchybar-popup(5) pattern):
#   - The `volume` anchor uses `click_script=$CONFIG_DIR/plugins/volume.sh toggle`.
#     Subscribing the anchor to `mouse.clicked` does NOT reliably deliver
#     clicks once popup rows are attached (sketchybar swallows them), so we
#     use the recommended click_script inline invocation.
#   - The `volume_slider` does subscribe `mouse.clicked volume_change`
#     (sliders explicitly support mouse.clicked per sketchybar-components(5)).
#   - Each popup row gets an inline `click_script=` set by `populate_popup`.

EXPANDED_WIDTH=200

ITEM="volume"
SLIDER="volume_slider"
POPUP_PREFIX="volume_output"

DEVICES_CACHE="/tmp/sketchybar_volume_devices.txt"
CURRENT_CACHE="/tmp/sketchybar_volume_current.txt"

# Shorten long device names for the bar label.
short_name() {
    echo "$1" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/'
}

# --- Audio source helpers ------------------------------------------------

# Synchronous fetch of the output-device list + current device. Writes
# $DEVICES_CACHE and $CURRENT_CACHE atomically (write-to-tmp then mv).
fetch_devices() {
    SwitchAudioSource -a -t output 2>/dev/null > "$DEVICES_CACHE.tmp"
    mv "$DEVICES_CACHE.tmp" "$DEVICES_CACHE"
    SwitchAudioSource -c 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

current_output() {
    [ -f "$CURRENT_CACHE" ] && cat "$CURRENT_CACHE" && return
    SwitchAudioSource -c 2>/dev/null
}

# Returns the value (on/off) of a sketchybar item's top-level `drawing`
# property. Filter -F'"' splits '"drawing": "on",' into ['...','drawing',
# ': ','on',', '] — $4 is the bare value. Robust against nested
# background/icon/popup drawing props (we take the first match which is
# always the item's geometry.drawing).
is_drawn() {
    sketchybar --query "$1" 2>/dev/null \
        | awk -F'"' '/"drawing":/ {print $4; exit}'
}

# --- Bar helpers ---------------------------------------------------------

# Guard against `osascript -e 'output volume of (get volume settings)'` returning
# the literal string "missing value" for some devices (e.g. external USB audio
# that doesn't expose a software level). Also ignore $INFO when it isn't a
# bare integer: sketchybar populates $INFO with a click-descriptor JSON for
# `mouse.clicked` events (`{"button":"left",...}`), which we must NOT treat
# as the volume number and render into the label.
get_volume() {
    RAW=""
    case "$INFO" in
        ''|*[!0-9]*) ;;
        *) RAW="$INFO" ;;
    esac
    if [ -z "$RAW" ]; then
        RAW=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
    fi
    if [ -z "$RAW" ] || [ "$RAW" = "missing value" ]; then
        echo "?"
    else
        echo "$RAW"
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

# Show State 2: slide out next to the still-visible label, show the popup.
# The label is kept on (label.drawing=on) so the user sees the original
# compact text right next to the slider, per the "don't hide the original
# item" requirement.
expand() {
    sketchybar --set "$ITEM" label.drawing=on popup.drawing=on
    sketchybar --set "$SLIDER" drawing=on slider.width="$EXPANDED_WIDTH"
    populate_popup
}

# Restore State 1.
collapse() {
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

# --- Entry points --------------------------------------------------------

# Called from a popup-row click_script after the user picks a device.
# Per the user spec: collapse back to the compact (idle) view on selection.
if [ "$1" = "switch" ]; then
    # Give CoreAudio a moment to register the newly-selected device.
    sleep 0.3
    fetch_devices
    collapse
    exit 0
fi

# Called from the `volume` text-item's inline `click_script=` to toggle
# between State 1 (idle) and State 2 (slider + device popup).
if [ "$1" = "toggle" ]; then
    SLIDER_DRAWN=$(is_drawn "$SLIDER")
    if [ "$SLIDER_DRAWN" = "on" ]; then
        collapse
    else
        # First ever click: lazily fetch the device list so the popup
        # populates immediately even before routine refresh has run.
        [ ! -f "$DEVICES_CACHE" ] && fetch_devices
        expand
    fi
    exit 0
fi

# Volume change event or init/routine.
if [ "$SENDER" = "volume_change" ] || [ -z "$SENDER" ] \
   || [ "$SENDER" = "forced" ] || [ "$SENDER" = "routine" ]; then
    [ ! -f "$DEVICES_CACHE" ] && fetch_devices
    # Cheap re-sync of current device so the cache matches reality if the
    # system default output was changed outside sketchybar.
    LIVE_CUR=$(SwitchAudioSource -c 2>/dev/null)
    if [ -n "$LIVE_CUR" ]; then
        echo "$LIVE_CUR" > "$CURRENT_CACHE"
    fi
    SLIDER_DRAWN=$(is_drawn "$SLIDER")
    VOL=$(get_volume)
    # Only push a number to the slider (sketchybar rejects non-numeric input
    # like "?" or "missing value", which would crash the slider display).
    case "$VOL" in
        ''|*[!0-9]*) ;;
        *) sketchybar --set "$SLIDER" slider.percentage="$VOL" ;;
    esac
    if [ "$SLIDER_DRAWN" != "on" ]; then
        render_idle_label
    fi
    exit 0
fi

# --- Mouse events (click only — no hover handlers) ----------------------

if [ "$SENDER" = "mouse.clicked" ]; then
    # Slider drag-release -> set system volume, keep State 2 expanded.
    # (Only the slider reaches this branch; the anchor uses click_script
    # which runs the `toggle` arg path above, NOT this subscription.)
    if [ "$NAME" = "$SLIDER" ] && [ -n "$PERCENTAGE" ]; then
        osascript -e "set volume output volume $PERCENTAGE"
        sketchybar --set "$SLIDER" slider.percentage="$PERCENTAGE"
        # Refresh the idle label in-place so the {output} >> {vol}% text
        # updates the moment the slider is released (it's still visible
        # next to the slider in State 2).
        OUT=$(current_output)
        SHORT=$(short_name "$OUT")
        [ -z "$SHORT" ] && SHORT="Audio"
        sketchybar --set "$ITEM" label="${SHORT} >> ${PERCENTAGE}%"
        exit 0
    fi
    # We only reach here for an unexpected `mouse.clicked` on a non-slider
    # item: re-render the idle label so we never leave a stale or junk
    # (eg. click-descriptor JSON) label visible to the user.
    render_idle_label
    exit 0
fi
