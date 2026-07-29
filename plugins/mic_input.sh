#!/bin/sh

# Merged mic level + mic input source control (click-only, synchronous).
#
# State 1 (default): bar shows text "{mic level}% << {input source}".
# State 2 (after click on text): the slider appears NEXT TO the text label
#                   (label stays visible) and the popup lists available
#                   input devices with the current one marked (● + bold).
# State 2 stays open until:
#   - the text item is clicked again (toggle back to State 1), OR
#   - a device row is clicked (switch device, then collapse to State 1).
# Dragging the slider updates mic input level and keeps State 2 open.
# No timers, no hover, no auto-dismiss.
#
# Delivery model (mirrors plugins/volume.sh — see comment there):
#   - The `mic` anchor uses `click_script=$CONFIG_DIR/plugins/mic_input.sh toggle`.
#   - The `mic_slider` subscribes `mouse.clicked` (sliders support it).
#   - Each popup row gets an inline `click_script=` set by `populate_popup`.

EXPANDED_WIDTH=200

ITEM="mic"
SLIDER="mic_slider"
POPUP_PREFIX="mic_input"

DEVICES_CACHE="/tmp/sketchybar_mic_inputs.txt"
CURRENT_CACHE="/tmp/sketchybar_mic_current.txt"

short_name() {
    echo "$1" | sed 's/MacBook Pro/MBP/; s/Realtek USB2.0/Realtek/; s/Alexey.s/Lex/'
}

# --- Source helpers ----------------------------------------------------

# Synchronous fetch of the input-device list + current input device.
fetch_devices() {
    SwitchAudioSource -a -t input 2>/dev/null > "$DEVICES_CACHE.tmp"
    mv "$DEVICES_CACHE.tmp" "$DEVICES_CACHE"
    SwitchAudioSource -c -t input 2>/dev/null > "$CURRENT_CACHE.tmp"
    mv "$CURRENT_CACHE.tmp" "$CURRENT_CACHE"
}

current_input() {
    [ -f "$CURRENT_CACHE" ] && cat "$CURRENT_CACHE" && return
    SwitchAudioSource -c -t input 2>/dev/null
}

# Returns the value (on/off) of a sketchybar item's top-level `drawing`
# property (see plugins/volume.sh for the implementation note).
is_drawn() {
    sketchybar --query "$1" 2>/dev/null \
        | awk -F'"' '/"drawing":/ {print $4; exit}'
}

# --- Bar helpers -------------------------------------------------------

# Guard against `osascript` returning the literal `missing value` for some
# input devices that don't expose a software input level.
get_mic_level() {
    RAW=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)
    if [ -z "$RAW" ] || [ "$RAW" = "missing value" ]; then
        echo "?"
    else
        echo "$RAW"
    fi
}

# Render State 1 label. Does NOT set `popup.drawing=off` (that's `collapse()`'s
# job); routine refresh calls here only when the slider is hidden, where the
# popup is already off — so the redundant `popup.drawing=off` would just be
# a wasted IPC and a duplicate during `collapse()`.
render_idle_label() {
    IN=$(current_input)
    SHORT=$(short_name "$IN")
    [ -z "$SHORT" ] && SHORT="Mic"
    MIC=$(get_mic_level)
    sketchybar --set "$ITEM" \
        label="${MIC}% << ${SHORT}" \
        label.drawing=on
    sketchybar --set "$SLIDER" drawing=off
}

# Show State 2: the slider appears next to the still-visible label, and the
# pre-populated popup appears in a single visible redraw (no progressive
# row-by-row fill). Order matters for redraw efficiency, per sketchybar-
# tips(5) ("After each configuration command, the bar is redrawn if needed"):
#   1. populate_popup() — set row content WHILE popup.drawing=off so the
#      per-row `sketchybar --set` calls happen off-screen (invisible).
#   2. Turn the slider ON first — bar layout shifts to accommodate it,
#      and that layout settles before the popup is shown.
#   3. Turn the popup ON — it appears already fully populated on the now
#      stable bar layout, in a single visible redraw.
expand() {
    populate_popup
    sketchybar --set "$SLIDER" drawing=on slider.width="$EXPANDED_WIDTH"
    sketchybar --set "$ITEM"   label.drawing=on popup.drawing=on
}

# Restore State 1, no duplicate IPCs:
#   1. batch-clear all 20 popup rows in one regex call (1 IPC)
#   2. hide the popup (1 IPC)
#   3. render_idle_label — sets the idle text + hides the slider (2 IPCs)
# Note: render_idle_label hides the slider, so we don't repeat it here.
collapse() {
    sketchybar --set "/${POPUP_PREFIX}_[0-9]/" drawing=off 2>/dev/null
    sketchybar --set "$ITEM"                  popup.drawing=off
    render_idle_label
}

# Fill popup rows, marking the current one with ● + bold. The 20 rows are
# cleared with one batched regex `--set` (instead of 20 separate IPC calls —
# see sketchybar-tips(5) on batching; sketchybar-items(5) supports `/REGEX/`
# as the `--set` target to address multiple items in one call). The per-row
# `drawing=on` calls below are unavoidable (different labels per row), but
# they happen WHILE the popup is hidden — so their redraws are invisible.
populate_popup() {
    sketchybar --set "/${POPUP_PREFIX}_[0-9]/" drawing=off 2>/dev/null

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

# --- Entry points ------------------------------------------------------

# Called from a popup-row click_script after picking a device.
# Per the user spec: collapse back to the compact (idle) view on selection.
if [ "$1" = "switch" ]; then
    # Give CoreAudio a moment to register the newly-selected device.
    sleep 0.3
    fetch_devices
    collapse
    exit 0
fi

# Called from the `mic` text-item's inline `click_script=` to toggle
# between State 1 (idle) and State 2 (slider + device popup).
if [ "$1" = "toggle" ]; then
    SLIDER_DRAWN=$(is_drawn "$SLIDER")
    if [ "$SLIDER_DRAWN" = "on" ]; then
        collapse
    else
        # First ever click: lazily fetch the device list.
        [ ! -f "$DEVICES_CACHE" ] && fetch_devices
        expand
    fi
    exit 0
fi

# Init (SENDER=forced on first run) or routine refresh (SENDER=routine).
if [ -z "$SENDER" ] || [ "$SENDER" = "forced" ] || [ "$SENDER" = "routine" ]; then
    [ ! -f "$DEVICES_CACHE" ] && fetch_devices
    # Cheap re-sync of current input device so the cache matches reality
    # if the system default input was changed outside sketchybar.
    LIVE_CUR=$(SwitchAudioSource -c -t input 2>/dev/null)
    if [ -n "$LIVE_CUR" ]; then
        echo "$LIVE_CUR" > "$CURRENT_CACHE"
    fi
    SLIDER_DRAWN=$(is_drawn "$SLIDER")
    MIC=$(get_mic_level)
    # Only push a number to the slider (sketchybar rejects non-numeric input).
    case "$MIC" in
        ''|*[!0-9]*) ;;
        *) sketchybar --set "$SLIDER" slider.percentage="$MIC" ;;
    esac
    if [ "$SLIDER_DRAWN" != "on" ]; then
        render_idle_label
    fi
    exit 0
fi

# --- Mouse events (click only — no hover handlers) --------------------

if [ "$SENDER" = "mouse.clicked" ]; then
    # Slider drag-release -> set mic input volume, keep State 2 expanded.
    # (Only the slider reaches this branch; the anchor uses click_script
    # which runs the `toggle` arg path above, NOT this subscription.)
    if [ "$NAME" = "$SLIDER" ] && [ -n "$PERCENTAGE" ]; then
        osascript -e "set volume input volume $PERCENTAGE"
        sketchybar --set "$SLIDER" slider.percentage="$PERCENTAGE"
        # Update the still-visible idle label so the {level}% << {src}
        # text reflects the new mic level the moment the slider releases.
        IN=$(current_input)
        SHORT=$(short_name "$IN")
        [ -z "$SHORT" ] && SHORT="Mic"
        sketchybar --set "$ITEM" label="${PERCENTAGE}% << ${SHORT}"
        exit 0
    fi
    # Unexpected `mouse.clicked` on a non-slider item: never leave a junk
    # (eg. click-descriptor JSON) label visible — re-render the idle label.
    render_idle_label
    exit 0
fi
