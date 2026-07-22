#!/bin/sh

STATE_FILE="/tmp/sketchybar-aerospace-state"

# Mouse hover
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --set space background.color=0xff484848
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  sketchybar --set space background.color=0xff333333
  exit 0
fi

# Event-driven or routine update
if [ "$SENDER" = "aerospace_workspace_change" ] || [ "$SENDER" = "routine" ]; then
  if [ -n "$FOCUSED_WORKSPACE" ]; then
    FOCUSED_WS="$FOCUSED_WORKSPACE"
  else
    FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
  fi

  if [ -f "$STATE_FILE" ]; then
    read -r LAST_FOCUSED < "$STATE_FILE" 2>/dev/null
    if [ "$FOCUSED_WS" = "$LAST_FOCUSED" ]; then
      exit 0
    fi
  fi
  echo "$FOCUSED_WS" > "$STATE_FILE"

  ALL_WS=$(aerospace list-workspaces --all 2>/dev/null)
  LIST=""
  for ws in $ALL_WS; do
    APPS=$(aerospace list-windows --workspace "$ws" 2>/dev/null | awk -F' \\| ' '{print $2}' | sort -u)
    if [ -z "$APPS" ] && [ "$ws" != "$FOCUSED_WS" ]; then
      continue
    fi
    if [ -z "$APPS" ]; then
      APPS="(empty)"
    fi
    TRUNCATED=""
    if [ "$APPS" != "(empty)" ]; then
      for app in $APPS; do
        if [ ${#app} -gt 15 ]; then
          app=$(echo "$app" | cut -c1-12)"..."
        fi
        TRUNCATED="$TRUNCATED $app"
      done
      TRUNCATED=$(echo "$TRUNCATED" | sed 's/^ //')
    else
      TRUNCATED="$APPS"
    fi
    if [ "$ws" = "$FOCUSED_WS" ]; then
      ENTRY="---$ws: $TRUNCATED---"
    else
      ENTRY="$ws: $TRUNCATED"
    fi
    if [ -z "$LIST" ]; then
      LIST="$ENTRY"
    else
      LIST="$LIST - $ENTRY"
    fi
  done

  [ -z "$LIST" ] && LIST="no workspaces"
  sketchybar --set space icon="$LIST" label.drawing=off
  exit 0
fi

# First run: build initial display
FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
echo "$FOCUSED_WS" > "$STATE_FILE"

ALL_WS=$(aerospace list-workspaces --all 2>/dev/null)
LIST=""
for ws in $ALL_WS; do
  APPS=$(aerospace list-windows --workspace "$ws" 2>/dev/null | awk -F' \\| ' '{print $2}' | sort -u)
  if [ -z "$APPS" ] && [ "$ws" != "$FOCUSED_WS" ]; then
    continue
  fi
  if [ -z "$APPS" ]; then
    APPS="(empty)"
  fi
  TRUNCATED=""
  if [ "$APPS" != "(empty)" ]; then
    for app in $APPS; do
      if [ ${#app} -gt 15 ]; then
        app=$(echo "$app" | cut -c1-12)"..."
      fi
      TRUNCATED="$TRUNCATED $app"
    done
    TRUNCATED=$(echo "$TRUNCATED" | sed 's/^ //')
  else
    TRUNCATED="$APPS"
  fi
  if [ "$ws" = "$FOCUSED_WS" ]; then
    ENTRY="---$ws: $TRUNCATED---"
  else
    ENTRY="$ws: $TRUNCATED"
  fi
  if [ -z "$LIST" ]; then
    LIST="$ENTRY"
  else
    LIST="$LIST - $ENTRY"
  fi
done

[ -z "$LIST" ] && LIST="no workspaces"
sketchybar --set space icon="$LIST" label.drawing=off
