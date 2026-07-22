#!/bin/sh

if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=0xff484848
    exit 0
elif [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=0xff333333
    exit 0
fi

LAYOUT=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep 'KeyboardLayout Name' | awk -F'= ' '{print $2}' | tr -d '";')

sketchybar --set "$NAME" label="$LAYOUT"
