#!/bin/sh
BATT=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep -i 'AC Power')

if [ -n "$CHARGING" ]; then
  sketchybar --set $NAME label="${BATT}% (charging)"
else
  sketchybar --set $NAME label="${BATT}%"
fi
