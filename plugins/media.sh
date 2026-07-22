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
  nowplaying-cli togglePlayPause
  exit 0
fi

JSON=$(nowplaying-cli get --json title artist app playbackRate 2>/dev/null)

if [ -z "$JSON" ]; then
  sketchybar --set "$NAME" drawing=off
  sketchybar --set media_prev drawing=off
  sketchybar --set media_next drawing=off
  exit 0
fi

TITLE=$(echo "$JSON" | jq -r '.title // empty')
ARTIST=$(echo "$JSON" | jq -r '.artist // empty')
APP=$(echo "$JSON" | jq -r '.app // empty')
RATE=$(echo "$JSON" | jq -r '.playbackRate // 0')

if [ -z "$TITLE" ]; then
  sketchybar --set "$NAME" drawing=off
  sketchybar --set media_prev drawing=off
  sketchybar --set media_next drawing=off
  exit 0
fi

if echo "$RATE" | grep -q '^[0-9.]*$' && [ "$(echo "$RATE" | awk '{print $1 + 0}')" -gt 0 ] 2>/dev/null; then
  ICON="▶"
else
  ICON="⏸"
fi

LABEL=""
if [ -n "$APP" ] && [ "$APP" != "null" ]; then
  LABEL="${APP}: ${TITLE}"
else
  LABEL="${TITLE}"
fi
if [ -n "$ARTIST" ] && [ "$ARTIST" != "null" ]; then
  LABEL="${LABEL} – ${ARTIST}"
fi

[ ${#LABEL} -gt 50 ] && LABEL="$(echo "$LABEL" | cut -c1-47)..."

sketchybar --set "$NAME" icon="$ICON" label="$LABEL" drawing=on
sketchybar --set media_prev drawing=on
sketchybar --set media_next drawing=on
