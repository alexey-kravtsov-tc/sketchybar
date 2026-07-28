#!/bin/sh

# Previous-track button. No hover, no popup, no timers.

if [ "$SENDER" = "mouse.clicked" ]; then
  nowplaying-cli previous
  exit 0
fi
