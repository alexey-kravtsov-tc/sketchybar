#!/bin/sh

if [ "$SENDER" = "volume_change" ] || [ -z "$SENDER" ]; then
    # When the system volume changes or on init, update the slider to match the system volume.
    # Use $INFO if available (for volume_change event), otherwise query osascript.
    if [ -n "$INFO" ]; then
        VOLUME="$INFO"
    else
        VOLUME=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
    fi
    sketchybar --set "$NAME" slider.percentage="$VOLUME" label="Vol: ${VOLUME}%"
elif [ "$SENDER" = "mouse.clicked" ]; then
    # User clicked/dragged slider -> Set system volume to the percentage from the slider.
    osascript -e "set volume output volume $PERCENTAGE"
    # Update slider and label immediately for feedback.
    sketchybar --set "$NAME" slider.percentage="$PERCENTAGE" label="Vol: ${PERCENTAGE}%"
fi