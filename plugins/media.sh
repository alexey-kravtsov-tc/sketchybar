#!/bin/sh

# SketchyBar media plugin (main item + popup panel).
#
# Behaviour:
#   - The bar item shows the now-playing track (icon = play/pause).
#   - Clicking the bar item toggles the popup panel (no more inline play/pause).
#   - The popup contains three rows: previous / play-pause / next.
#   - Popup rows are populated and updated via this same script.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
POPUP_ROWS="media_popup_0 media_popup_1 media_popup_2"
HOVER_FLAG="/tmp/sketchybar_media_hover"

# ---------------------------------------------------------------------------
# Playback helpers
# ---------------------------------------------------------------------------

render_off() {
  sketchybar --set media drawing=off popup.drawing=off 2>/dev/null
  for r in $POPUP_ROWS; do
    sketchybar --set "$r" drawing=off 2>/dev/null
  done
}

populate_popup() {
  JSON=$(nowplaying-cli get --json title artist app playbackRate 2>/dev/null)
  RATE=$(echo "$JSON" | jq -r '.playbackRate // 0' 2>/dev/null)
  if echo "$RATE" | grep -qE '^[0-9.]+$' \
     && [ "$(echo "$RATE" | awk '{print int($1)}')" -gt 0 ] 2>/dev/null; then
    PLAY_LABEL="Pause"
    PLAY_ICON="⏸"
  else
    PLAY_LABEL="Play"
    PLAY_ICON="▶"
  fi

  # Row 0: previous
  sketchybar --set media_popup_0 drawing=on \
             icon="⏮" \
             label="Previous" \
             click_script="nowplaying-cli previous; $CONFIG_DIR/plugins/media.sh popup" \
             2>/dev/null

  # Row 1: play/pause toggle
  sketchybar --set media_popup_1 drawing=on \
             icon="$PLAY_ICON" \
             label="$PLAY_LABEL" \
             click_script="nowplaying-cli togglePlayPause; $CONFIG_DIR/plugins/media.sh popup" \
             2>/dev/null

  # Row 2: next
  sketchybar --set media_popup_2 drawing=on \
             icon="⏭" \
             label="Next" \
             click_script="nowplaying-cli next; $CONFIG_DIR/plugins/media.sh popup" \
             2>/dev/null
}

# ---------------------------------------------------------------------------
# Event dispatch
# ---------------------------------------------------------------------------

# Invert a popup row's colors (hover effect).
hover_row_on() {
  sketchybar --set "$1" \
    background.color=0xffeeeeee \
    label.color=0xff222222 \
    icon.color=0xff222222 2>/dev/null
}

# Restore a popup row's default (dark pill) colors.
hover_row_off() {
  sketchybar --set "$1" \
    background.color=0xff222222 \
    label.color=0xffeeeeee \
    icon.color=0xffffffff 2>/dev/null
}

case "$SENDER" in
  popup)
    # Force-refresh popup content (used by click scripts).
    populate_popup
    exit 0
    ;;

  mouse.entered)
    case "$NAME" in
      media_popup_[0-9]) echo "1" > "$HOVER_FLAG"; hover_row_on "$NAME"; exit 0 ;;
    esac
    if [ "$NAME" = "media" ]; then
      echo "1" > "$HOVER_FLAG"
      populate_popup
      sketchybar --set media popup.drawing=on 2>/dev/null
    fi
    exit 0
    ;;

  mouse.exited)
    case "$NAME" in
      media_popup_[0-9]) echo "0" > "$HOVER_FLAG"; hover_row_off "$NAME"; exit 0 ;;
    esac
    if [ "$NAME" = "media" ]; then
      echo "0" > "$HOVER_FLAG"
      ( sleep 1
        HOVER=$(cat "$HOVER_FLAG" 2>/dev/null)
        if [ "$HOVER" != "1" ]; then
          sketchybar --set media popup.drawing=off 2>/dev/null
        fi
      ) &
    fi
    exit 0
    ;;

  mouse.clicked)
    if [ "$NAME" = "media" ]; then
      populate_popup
      sketchybar --set media popup.drawing=toggle 2>/dev/null
    fi
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Routine / media_change refresh: update the main bar item + popup rows
# ---------------------------------------------------------------------------

JSON=$(nowplaying-cli get --json title artist app playbackRate 2>/dev/null)

if [ -z "$JSON" ] || [ "$(echo "$JSON" | jq -r '.title // empty' 2>/dev/null)" = "" ]; then
  render_off
  exit 0
fi

TITLE=$(echo "$JSON"  | jq -r '.title   // empty' 2>/dev/null)
ARTIST=$(echo "$JSON" | jq -r '.artist  // empty' 2>/dev/null)
APP=$(echo "$JSON"    | jq -r '.app     // empty' 2>/dev/null)
RATE=$(echo "$JSON"   | jq -r '.playbackRate // 0' 2>/dev/null)

if echo "$RATE" | grep -qE '^[0-9.]+$' \
   && [ "$(echo "$RATE" | awk '{print int($1)}')" -gt 0 ] 2>/dev/null; then
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

sketchybar --set media icon="$ICON" label="$LABEL" drawing=on 2>/dev/null

# Keep popup rows fresh in case the popup was open when the track changed.
populate_popup
