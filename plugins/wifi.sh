#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xff484848
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333
    exit 0
fi

WIFI_POWER=$(networksetup -getairportpower en0 2>/dev/null)
WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null)

if echo "$WIFI_POWER" | grep -qi "On" && [ -n "$WIFI_IP" ]; then
    sketchybar --set $NAME label="WiFi"
elif echo "$WIFI_POWER" | grep -qi "Off"; then
    sketchybar --set $NAME label="WiFi: off"
else
    sketchybar --set $NAME label="WiFi: disconnected"
fi
