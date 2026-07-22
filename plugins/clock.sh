#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xff484848
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333
    exit 0
fi

sketchybar --set $NAME label="$(date '+%a %b %d  %H:%M')"
