#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xff484848
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333
    exit 0
elif [ "$SENDER" = "mouse.clicked" ]; then
    sketchybar --set "$NAME" popup.drawing=toggle

    TMPFILE=$(mktemp)
    gws calendar +agenda --days 30 --format json 2>/dev/null |
        jq -r '.events[0:10][] | [.summary, .start] | @tsv' > "$TMPFILE"

    i=0
    while IFS='	' read -r summary start; do
        summary=$(echo "$summary" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if echo "$start" | grep -q T; then
            start_stripped=$(echo "$start" | sed 's/\([+-][0-9]\{2\}\):\([0-9]\{2\}\)/\1\2/')
            start_fmt=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$start_stripped" "+%b %d %H:%M" 2>/dev/null || echo "$start")
        else
            start_fmt=$(date -j -f "%Y-%m-%d" "$start" "+%b %d" 2>/dev/null || echo "$start")
        fi
        sketchybar --set "clock_event_$i" label="${summary}  ${start_fmt}" \
                                        drawing=on
        i=$((i+1))
    done < "$TMPFILE"
    rm -f "$TMPFILE"

    while [ "$i" -lt 10 ]; do
        sketchybar --set "clock_event_$i" drawing=off
        i=$((i+1))
    done
    exit 0
fi

sketchybar --set $NAME label="$(date '+%a %b %d  %H:%M')"
