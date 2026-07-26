# Shared hover-invert helpers for root bar items.
#
# apply_hover_on ITEM    -> paint a light pill, swap label/icon to dark.
# apply_hover_off ITEM   -> restore the default dark pill + light text.
#
# Source this from a plugin and call from its mouse.entered/mouse.exited
# handler for the root bar item. The colors/values here must stay in sync
# with the --default styling in sketchybarrc.

apply_hover_on() {
    sketchybar --set "$1" \
        background.color=0xffeeeeee \
        background.height=18 \
        label.color=0xff222222 \
        icon.color=0xff222222 2>/dev/null
}

apply_hover_off() {
    sketchybar --set "$1" \
        background.color=0xff333333 \
        background.height=16 \
        label.color=0xffeeeeee \
        icon.color=0xffffffff 2>/dev/null
}
