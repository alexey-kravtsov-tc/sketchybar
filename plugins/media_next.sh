#!/bin/sh

# Next-track button. No hover, no popup, no timers.

if [ "$SENDER" = "mouse.clicked" ]; then
  nowplaying-cli next
  exit 0
fi
