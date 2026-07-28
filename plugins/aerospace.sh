#!/bin/sh

# Temporary state file to avoid unnecessary updates
STATE_FILE="/tmp/sketchybar-aerospace-state"

# Resolve the focused workspace (may be passed in from events)
if [ -n "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WS="$FOCUSED_WORKSPACE"
else
  FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
fi

# --- Mouse click handling for per‑workspace items -------------------------------
if [ "$NAME" != "aerospace_handler" ]; then
  if [ "$SENDER" = "mouse.clicked" ]; then
    WS_ID="${NAME#ws}"
    aerospace workspace "$WS_ID" 2>/dev/null
    exit 0
  fi
  exit 0
fi

# --- Workspace sync – runs for aerospace_handler (first run, routine, or change) ----
# Throttle updates if the focused workspace hasn't changed (except for routine events)
if [ -f "$STATE_FILE" ]; then
  read -r LAST_FOCUSED < "$STATE_FILE" 2>/dev/null
  if [ "$FOCUSED_WS" = "$LAST_FOCUSED" ] && [ "$SENDER" != "routine" ]; then
    exit 0
  fi
fi

# Persist the new focused workspace
printf "%s" "$FOCUSED_WS" > "$STATE_FILE"

# Retrieve all workspaces and iterate over them
ALL_WS=$(aerospace list-workspaces --all 2>/dev/null)

for ws in $ALL_WS; do
  # Fetch unique app names for this workspace
  APPS=$(aerospace list-windows --workspace "$ws" 2>/dev/null | awk -F'\\| ' '{print $2}' | sort -u)

  # Skip empty workspaces that are not the focused one
  if [ -z "$APPS" ] && [ "$ws" != "$FOCUSED_WS" ]; then
    # Remove any stray items for workspaces that no longer have windows
    sketchybar --remove "ws${ws}" 2>/dev/null
    continue
  fi

  # Build a display string of app names, truncating long names
  if [ -z "$APPS" ]; then
    APP_STR="(empty)"
  else
    APP_STR=""
    for app in $APPS; do
      if [ ${#app} -gt 15 ]; then
        app="${app:0:12}..."
      fi
      APP_STR="$APP_STR $app"
    done
    APP_STR=$(echo "$APP_STR" | sed 's/^ //')
  fi

  # Decide background colour for this workspace
  BG_COLOR="0xff333333"
  if [ "$ws" = "$FOCUSED_WS" ]; then
    BG_COLOR="0xff5a5a5a"
  fi

  # Check if the item already exists
  if sketchybar --query "ws${ws}" >/dev/null 2>&1; then
    # Update the existing item
    sketchybar --set "ws${ws}" label="${ws}: $APP_STR" background.color="$BG_COLOR"
  else
    # Create a new item for this workspace
    sketchybar --add item "ws${ws}" left \
               --set "ws${ws}" \
               label="${ws}: $APP_STR" \
               background.color="$BG_COLOR" \
               script="$CONFIG_DIR/plugins/aerospace.sh"
    sketchybar --subscribe "ws${ws}" mouse.clicked
  fi

done
