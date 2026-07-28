#!/bin/sh

refresh_events() {
    TMPFILE=$(mktemp)
    gws calendar +agenda --days 30 --format json 2>/dev/null |
        jq -r '
            .events |
            sort_by(.start) |
            group_by(.summary) | map(first) |
            sort_by(.start) |
            .[0:10][] |
            [.summary, .start] | @tsv
        ' > "$TMPFILE"

    now=$(date +%s)
    i=0
    while IFS='	' read -r summary start; do
        summary=$(echo "$summary" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if echo "$start" | grep -q T; then
            # Normalize timezone: "Z" → "+0000", remove colon from "+HH:MM"
            start_norm=$(echo "$start" | sed 's/Z$/+0000/; s/\([+-][0-9]\{2\}\):\([0-9]\{2\}\)/\1\2/')
            start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$start_norm" +%s 2>/dev/null)
            if [ -z "$start_epoch" ]; then
                start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$start" | sed 's/\([+-][0-9]\{2\}\):[0-9]\{2\}\|Z$//')" +%s 2>/dev/null)
            fi
        else
            start_epoch=$(date -j -f "%Y-%m-%d" "$start" +%s 2>/dev/null)
        fi
        if [ -n "$start_epoch" ]; then
            diff=$((start_epoch - now))
            if [ $diff -lt 0 ]; then
                rel="now"
            elif [ $diff -lt 3600 ]; then
                minutes=$(( (diff + 30) / 60 ))
                rel="in ${minutes} min"
            elif [ $diff -lt 86400 ]; then
                hours=$(( (diff + 1800) / 3600 ))
                rel="in ${hours} h"
            else
                days=$(( (diff + 43200) / 86400 ))
                rel="in ${days} d"
            fi
        else
            rel=""
        fi
        sketchybar --set "clock_event_$i" label="${summary}  ${rel}" \
                                        drawing=on
        i=$((i+1))
    done < "$TMPFILE"
    rm -f "$TMPFILE"

    while [ "$i" -lt 10 ]; do
        sketchybar --set "clock_event_$i" drawing=off
        i=$((i+1))
    done
}

if [ "$SENDER" = "mouse.clicked" ]; then
    sketchybar --set "$NAME" popup.drawing=toggle
    refresh_events
    exit 0
elif [ "$SENDER" = "routine" ] || [ "$SENDER" = "update" ]; then
    refresh_events
fi

sketchybar --set $NAME label="$(date '+%a %b %d  %H:%M')"
