#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xff484848
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333
    exit 0
elif [ "$SENDER" = "mouse.clicked" ]; then
    osascript -e "set volume output muted (not output muted of (get volume settings))"
    exit 0
fi

VOL=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
MUTED=$(osascript -e "output muted of (get volume settings)" 2>/dev/null)

if [ "$MUTED" = "true" ]; then
  sketchybar --set $NAME label="Muted"
else
  sketchybar --set $NAME label="Vol: ${VOL}%"
fi
