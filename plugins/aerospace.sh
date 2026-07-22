#!/bin/sh

FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
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

sketchybar --set "$NAME" icon="$LIST" label.drawing=off
