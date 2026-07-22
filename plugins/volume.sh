#!/bin/sh
VOL=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
MUTED=$(osascript -e "output muted of (get volume settings)" 2>/dev/null)

if [ "$MUTED" = "true" ]; then
  sketchybar --set $NAME label="Muted"
else
  sketchybar --set $NAME label="Vol: ${VOL}%"
fi
