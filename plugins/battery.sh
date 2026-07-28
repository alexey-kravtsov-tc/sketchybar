#!/bin/sh

# Battery charge indicator. No interaction (no hover, no popup).
# `update_freq=30` on the item triggers a routine refresh of the label.

BATT=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep -i 'AC Power')

if [ -n "$CHARGING" ]; then
  sketchybar --set $NAME label="++ ${BATT}%"
else
  sketchybar --set $NAME label="-- ${BATT}%"
fi
