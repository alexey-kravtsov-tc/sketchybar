#!/bin/sh

FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
ALL_WS=$(aerospace list-workspaces --all 2>/dev/null)

LABEL=""
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
    LABEL="$LABEL [$ws: $TRUNCATED]"
done

LABEL=$(echo "$LABEL" | sed 's/^ //')
[ -z "$LABEL" ] && LABEL="[no workspaces]"

sketchybar --set "$NAME" icon="$FOCUSED_WS" label="$LABEL"
