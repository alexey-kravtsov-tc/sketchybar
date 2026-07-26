#!/bin/sh

. "$CONFIG_DIR/plugins/_hover.sh" 2>/dev/null || . "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/_hover.sh"

if [ "$SENDER" = "mouse.entered" ]; then
    apply_hover_on "$NAME"
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    apply_hover_off "$NAME"
    exit 0
fi

BATT=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep -i 'AC Power')

if [ -n "$CHARGING" ]; then
  sketchybar --set $NAME label="++ ${BATT}%"
else
  sketchybar --set $NAME label="-- ${BATT}%"
fi
