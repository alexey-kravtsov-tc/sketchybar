#!/bin/sh

# WiFi status indicator. Click handling lives entirely in the `click_script`
# set on the `wifi` item in sketchybarrc (opens the macOS Network System
# Settings pane). This script just renders a status label on routine /
# init. No popup, no hover, no timers.

WIFI_POWER=$(networksetup -getairportpower en0 2>/dev/null)
WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null)

if echo "$WIFI_POWER" | grep -qi "On" && [ -n "$WIFI_IP" ]; then
    sketchybar --set $NAME label="WiFi"
elif echo "$WIFI_POWER" | grep -qi "Off"; then
    sketchybar --set $NAME label="WiFi: off"
else
    sketchybar --set $NAME label="WiFi: disconnected"
fi
