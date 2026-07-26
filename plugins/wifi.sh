#!/bin/sh

# SketchyBar WiFi plugin.
#
# - Bar item shows the joined SSID (or "WiFi: off" / "..." while scanning).
# - Hovering the bar item opens a popup listing up to 20 nearby networks,
#   sorted by signal strength. Scanning is delegated to:
#       plugins/swift/wifi_scan.swift   (CoreWLAN, no keychain, no join)
#   Clicking a popup row simply opens the macOS Wi-Fi settings panel so the
#   OS handles the connection (and any password prompt) natively.
# - Popup fades out 1s after the cursor leaves both the bar item and the popup.
#
# We deliberately do NOT attempt to join networks or read passwords from the
# keychain from here: macOS blocks/sandbox-blocks those paths from a non-GUI
# process and would hang on the keychain authorization prompt.

SCAN_SCRIPT="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/swift/wifi_scan.swift"
CACHE_FILE="/tmp/sketchybar_wifi_networks.txt"
HOVER_FLAG="/tmp/sketchybar_wifi_hover"

# Single-instance tags for background workers so we can pkill -f rearm safely
# across rapid hover/exited/routine events (avoids stacking swift scans / sleep
# subshells on top of each other).
SCAN_TAG="SKETCHYBAR_WIFI_SCAN"
TIMER_TAG="SKETCHYBAR_WIFI_TIMER"
CONFIG_DIRNorm="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# ---------------------------------------------------------------------------
# Scan / cache helpers
# ---------------------------------------------------------------------------
#
# wifi_scan.swift output:
#   Line 1:  "OFF"                                   if Wi-Fi power is off
#           "CURRENT: <ssid>"                        otherwise (ssid may be empty)
#   Lines 2+: "<rssi> | <security> | <ssid>"         nearby networks (excluding
#                                                  the currently-associated one)

scan_networks() {
  swift "$SCAN_SCRIPT" > "$CACHE_FILE.tmp" 2>/dev/null
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
}

# Echo the cached "OFF" / "CURRENT: <ssid>" value or empty string if no cache.
head_cache_status() {
  [ -f "$CACHE_FILE" ] || return 0
  head -1 "$CACHE_FILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Popup population
# ---------------------------------------------------------------------------

populate_popup() {
  # Hide every row first.
  i=0
  while [ "$i" -lt 20 ]; do
    sketchybar --set "wifi_popup_$i" drawing=off 2>/dev/null
    i=$((i + 1))
  done

  if [ ! -f "$CACHE_FILE" ] || [ ! -s "$CACHE_FILE" ]; then
    sketchybar --set "wifi_popup_0" drawing=on label="Scanning..."
    return
  fi

  STATUS_LINE=$(head -1 "$CACHE_FILE" 2>/dev/null)
  case "$STATUS_LINE" in
    OFF)
      sketchybar --set "wifi_popup_0" drawing=on \
        label="WiFi is off — click to enable" \
        click_script="networksetup -setairportpower ${WIFI_IF:-en0} on; sleep 2; \
                       SENDER=refresh NAME=wifi CONFIG_DIR='${CONFIG_DIR:-$HOME/.config/sketchybar}' \
                       '${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/wifi.sh'; \
                       sketchybar --set wifi popup.drawing=off"
      return
      ;;
  esac

  # All lines are network rows (no CURRENT: header anymore — see
  # swift/wifi_scan.swift).
  i=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$i" -ge 20 ] && break

    # line format: "<rssi> | <sec> | <ssid>" — SSID may itself contain " | "
    SIGNAL=$(echo "$line" | awk -F' \\| ' '{print $1}')
    SEC_TAG=$(echo "$line"  | awk -F' \\| ' '{print $2}')
    SSID=$(echo "$line"    | awk -F' \\| ' '{
            for (n=3; n<=NF; n++) {
              if (n>3) printf " | ";
              printf "%s", $n;
            }
          }')
    [ -z "$SSID" ] && continue

    # Compact signal level so the column is stable-width.
    case "$SIGNAL" in
      '' )          BAR="? " ;;
      *)
        if [ "$SIGNAL" -ge -50 ]; then BAR="●●●"
        elif [ "$SIGNAL" -ge -65 ]; then BAR="●●○"
        elif [ "$SIGNAL" -ge -75 ]; then BAR="●○○"
        else BAR="○○○"
        fi ;;
    esac

    LABEL="${BAR}  ${SEC_TAG}  ${SSID}"
    # Clicking just opens the OS Wi-Fi settings; the OS handles the connection
    # and any password prompt natively.
    sketchybar --set "wifi_popup_$i" \
        drawing=on \
        label="$LABEL" \
        click_script="open 'x-apple.systempreferences:com.apple.wifi'; \
                       sketchybar --set wifi popup.drawing=off" \
        2>/dev/null
    i=$((i + 1))
  done < "$CACHE_FILE"
}

# ---------------------------------------------------------------------------
# Bar item label: prefer networksetup's joined SSID (works on some macOS
# versions), fall back to power+IP state on macOS 26 where the SSID is
# redacted from CLI/script sources.
# ---------------------------------------------------------------------------

refresh_bar_label() {
  WIFI_IF="${WIFI_IF:-en0}"
  WIFI_POWER=$(networksetup -getairportpower "$WIFI_IF" 2>/dev/null)
  if echo "$WIFI_POWER" | grep -qi "Off"; then
    sketchybar --set "$NAME" label="WiFi: off"
    return
  fi

  # Try `networksetup -getairportnetwork` — on some macOS versions this still
  # returns the real SSID. On macOS 26 it returns "not associated" or
  # redacted even when connected; we'll fall through to power/IP state.
  SSID=$(networksetup -getairportnetwork "$WIFI_IF" 2>/dev/null \
         | sed -n 's/^Current Wi-Fi Network: //p')
  # Reject placeholder redacted strings from macOS privacy filtering.
  case "$SSID" in
    ""|"<"*">") SSID="" ;;
  esac
  if [ -n "$SSID" ]; then
    SHORT="$SSID"
    [ ${#SHORT} -gt 20 ] && SHORT="$(printf '%s' "$SHORT" | cut -c1-17)..."
    sketchybar --set "$NAME" label="$SHORT"
    return
  fi

  # Fall back to IP-based state — en0 having an IP strongly implies Wi-Fi
  # is associated (especially on machines where en0 is the Wi-Fi iface).
  WIFI_IP=$(ipconfig getifaddr "$WIFI_IF" 2>/dev/null)
  if [ -n "$WIFI_IP" ]; then
    sketchybar --set "$NAME" label="WiFi"
  else
    sketchybar --set "$NAME" label="WiFi: disconnected"
  fi
}

# ---------------------------------------------------------------------------
# Background worker guards: single-instance scan + popup-close timer.
# Uses pkill -f on a unique tag (matches our `exec -a` marker) so concurrent
# invocations cannot pile up children.  Mirrors plugins/volume.sh.
# ---------------------------------------------------------------------------

# Kill any in-flight wifi scan.
kill_scan()  { pkill -f "$SCAN_TAG"  2>/dev/null; }
# Kill the pending popup-close timer.
kill_timer() { pkill -f "$TIMER_TAG" 2>/dev/null; }

# Spawn (or re-spawn) a single scan in the background. After it finishes, if
# the popup is still open, repopulate it.
start_scan() {
    kill_scan
    (
        exec -a "$SCAN_TAG" sh -c '
            swift "'"$SCAN_SCRIPT"'" > "'"$CACHE_FILE"'.tmp" 2>/dev/null
            mv "'"$CACHE_FILE"'.tmp" "'"$CACHE_FILE"'"
            POPUP=$(sketchybar --query wifi 2>/dev/null \
                    | grep -o "\"drawing\" : \"[a-z]*\"" | head -1)
            if echo "$POPUP" | grep -q "\"on\""; then
               "'"$CONFIG_DIRNorm"'"/plugins/wifi.sh __refresh_popup
            fi
        '
    ) 2>/dev/null &
    disown 2>/dev/null
}

# Spawn a 1s popup-close timer (cancelled by kill_timer on re-entry).
start_timer() {
    kill_timer
    (
        exec -a "$TIMER_TAG" sh -c '
            sleep 1
            if [ "$(cat '"$HOVER_FLAG"' 2>/dev/null)" = "1" ]; then exit 0; fi
            sketchybar --set wifi popup.drawing=off 2>/dev/null
        '
    ) 2>/dev/null &
    disown 2>/dev/null
}

# Hidden entry-points invoked by the background workers.
if [ "$1" = "__refresh_popup" ]; then
    populate_popup
    exit 0
fi

# ---------------------------------------------------------------------------
# Event dispatch
# ---------------------------------------------------------------------------

if [ "$SENDER" = "refresh" ]; then
  refresh_bar_label
  exit 0
fi

if [ "$SENDER" = "mouse.entered" ]; then
  case "$NAME" in
    wifi_popup_[0-9]*) echo "1" > "$HOVER_FLAG"; kill_timer; exit 0 ;;
  esac
  echo "1" > "$HOVER_FLAG"
  kill_timer
  # Close any sibling popups (audio popups etc.)
  sketchybar --set volume    popup.drawing=off 2>/dev/null
  sketchybar --set mic        popup.drawing=off 2>/dev/null
  populate_popup
  sketchybar --set wifi popup.drawing=on 2>/dev/null
  # Trigger a fresh scan in the background; start_scan is single-instance.
  start_scan
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ]; then
  echo "0" > "$HOVER_FLAG"
  start_timer
  exit 0
fi

# ---------------------------------------------------------------------------
# routine / init: refresh the bar item label from the cache; if the popup is
# open, refresh the rows too. Refresh the cache in the background at most
# once per routine tick (update_freq=10s in sketchybarrc). Skip the scan if
# the cache is fresh (<30s old).
# ---------------------------------------------------------------------------

refresh_bar_label

POPUP=$(sketchybar --query wifi 2>/dev/null \
        | grep -o '"drawing" : "[a-z]*"' | head -1)
if echo "$POPUP" | grep -q '"on"'; then
  populate_popup
fi

NEEDS_SCAN=0
if [ ! -f "$CACHE_FILE" ]; then
  NEEDS_SCAN=1
else
  CACHED_MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - CACHED_MTIME))
  [ "$AGE" -gt 30 ] && NEEDS_SCAN=1
fi
[ "$NEEDS_SCAN" = "1" ] && start_scan
