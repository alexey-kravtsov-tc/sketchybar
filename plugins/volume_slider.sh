#!/bin/sh

if [ "$SENDER" = "volume_change" ]; then
    VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
    sketchybar --set $NAME slider.percentage=$VOL label="Vol: ${VOL}%"
elif [ "$SENDER" = "mouse.clicked" ]; then
    # $PERCENTAGE is set by SketchyBar for slider clicks/drags
    osascript -e "set volume output volume $PERCENTAGE"
    sketchybar --set $NAME slider.percentage=$PERCENTAGE label="Vol: ${PERCENTAGE}%"
fi