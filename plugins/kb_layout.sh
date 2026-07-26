#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xffeeeeee label.color=0xff222222 icon.color=0xff222222
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333 label.color=0xffeeeeee icon.color=0xffffffff
    exit 0
elif [ "$SENDER" = "mouse.clicked" ]; then
    # Optimistic: show next layout immediately, then actually switch
    CURRENT_LAYOUT=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep 'KeyboardLayout Name' | awk -F'= ' '{print $2}' | tr -d '";')
    ALL_LAYOUTS=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleEnabledInputSources 2>/dev/null | grep 'KeyboardLayout Name' | awk -F'= ' '{print $2}' | tr -d '";')

    NEXT_LAYOUT=$(echo "$ALL_LAYOUTS" | awk -v cur="$CURRENT_LAYOUT" '{ if (found) { print; exit } if ($0 == cur) found=1 }')
    if [ -z "$NEXT_LAYOUT" ]; then
        NEXT_LAYOUT=$(echo "$ALL_LAYOUTS" | head -1)
    fi

    sketchybar --set "$NAME" label="$NEXT_LAYOUT"
    osascript -e 'tell application "System Events" to key code 49 using {control down}'
    exit 0
fi

LAYOUT=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep 'KeyboardLayout Name' | awk -F'= ' '{print $2}' | tr -d '";')

sketchybar --set "$NAME" label="$LAYOUT"
