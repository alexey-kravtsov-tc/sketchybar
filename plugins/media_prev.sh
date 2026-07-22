#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --set "$NAME" background.color=0xff484848
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  sketchybar --set "$NAME" background.color=0xff333333
  exit 0
fi

if [ "$SENDER" = "mouse.clicked" ]; then
  nowplaying-cli previous
  exit 0
fi
