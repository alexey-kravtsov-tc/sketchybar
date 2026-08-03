#!/bin/sh

# SketchyBar app launcher (click-only, no timers / no routine refresh).
#
# Behaviour:
#   - The `launcher` bar item shows a static ⌘ label.
#   - Clicking it when the popup is CLOSED: repopulates rows from disk,
#     then opens the popup.
#   - Clicking it when the popup is ALREADY OPEN: closes the popup
#     immediately — no repopulate, no toggle flicker.
#   - Clicking a row runs `open -a '<path>'` and closes the popup.
#   - No `update_freq`, no `routine` subscription: the file system is read
#     only when the user opens the popup (so no background cost).
#
# Invocation:
#   launcher.sh toggle     — anchor click: open (with repopulate) or close
#   launcher.sh populate   — populate rows from disk (anytime, idempotent)

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
POPUP_PREFIX="launcher_app"
LIST_FILE="/tmp/sketchybar-launcher-list"
MAX_ROWS=40

# Scan /Applications and ~/Applications for *.app, dedupe by basename, sort
# case-insensitively, cap at MAX_ROWS. Output TSV: "<lowercased name>\t<path>".
scan_apps() {
    {
        ls -d /Applications/*.app 2>/dev/null
        ls -d "$HOME/Applications"/*.app 2>/dev/null
    } | awk -F/ '{
        n = $NF
        sub(/\.app$/, "", n)
        print tolower(n) "\t" $0
    }' | sort -u -k1,1 -k2 | head -n "$MAX_ROWS"
}

# Populate the popup rows. Clears all 40 rows with one batched regex --set
# (see sketchybar-tips(5) on batching; sketchybar-items(5) supports
# /REGEX/ as the --set target to address multiple items in one call),
# then sets label + click_script for each present app.
populate() {
    scan_apps > "$LIST_FILE"

    sketchybar --set "/${POPUP_PREFIX}_[0-9]/" drawing=off 2>/dev/null

    i=0
    while IFS='	' read -r name path; do
        [ -z "$path" ] && continue
        # Escape single quotes for the click_script wrapper. macOS app
        # bundles cannot contain a single quote in their name (Finder
        # forbids it), so this is belt-and-braces.
        safe_path=$(printf "%s" "$path" | sed "s/'/'\\\\''/g")
        sketchybar --set "${POPUP_PREFIX}_$i" \
            drawing=on \
            label="$name" \
            click_script="open -a '$safe_path'; sketchybar --set launcher popup.drawing=off"
        i=$((i + 1))
    done < "$LIST_FILE"
}

# Avoid the close-then-reopen flicker: when the user clicks the anchor
# while the popup is already open, we want it to just close — NOT repopulate
# (which redraws every row off-screen) and then toggle. So `toggle` checks
# the current popup state: if open, ONLY close; if closed, populate then open.
toggle_popup() {
    current=$(sketchybar --query launcher 2>/dev/null | python3 -c \
        'import sys,json; print(json.load(sys.stdin)["popup"].get("drawing","off"))' \
        2>/dev/null)
    if [ "$current" = "on" ]; then
        sketchybar --set launcher popup.drawing=off
    else
        populate
        sketchybar --set launcher popup.drawing=on
    fi
}

case "$1" in
    toggle)
        toggle_popup
        ;;
    populate)
        populate
        ;;
    *)
        exit 0
        ;;
esac
