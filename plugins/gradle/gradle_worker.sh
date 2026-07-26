#!/usr/bin/env zsh
# Transient background worker for a single Gradle daemon PID.
# Renders up to 15 popup rows (one popup item per log line) for streaming
# preview, and self-terminates when the daemon returns to idle or dies.

PID="$1"
[[ -z "$PID" ]] && exit 1

GRADLE_DAEMON_DIR="$HOME/.gradle/daemon"
ITEM_NAME="gradle"
POPUP_PREFIX="gradle.popup.${PID}"
STATE_FILE="/tmp/sketchybar_gradle_worker_${PID}.pid"
POLL_INTERVAL=2
PREVIEW_LINES=15
LINE_WIDTH=50  # cols; ~480px at JetBrains Mono 12pt
MAX_LIFETIME=7200  # hard cap in seconds (2 hours) to bound orphan risk.

START_MARKER='The daemon has started executing the build'
FINISH_MARKER='The daemon has finished executing the build'
IDLE_MARKER='Marking the daemon as idle'

# Note our own start time so we can self-terminate if we outlive any
# reasonable build (e.g. parent gradle.sh crashed mid-loop, the daemon
# PID was reused by an unrelated process, or the daemon was kill -9'd
# and the log never sees the finish marker).
WORKER_START=$(date +%s)

cleanup() {
  local i
  for (( i = 0; i < PREVIEW_LINES; i++ )); do
    sketchybar --remove "${POPUP_PREFIX}.${i}" 2>/dev/null
  done
  rm -f "$STATE_FILE"
  exit 0
}
trap cleanup TERM INT EXIT

# Locate the log file for this PID.
log_file=""
for version in "$GRADLE_DAEMON_DIR"/*(/N); do
  candidate="$version/daemon-${PID}.out.log"
  [[ -f "$candidate" ]] && { log_file="$candidate"; break; }
done
[[ -z "$log_file" ]] && cleanup

# Pre-create the 15 popup row items (plain dark box).
for (( i = 0; i < PREVIEW_LINES; i++ )); do
  sketchybar --add item "${POPUP_PREFIX}.${i}" popup."$ITEM_NAME" \
             --set "${POPUP_PREFIX}.${i}" \
                    drawing=off \
                    width=480 \
                    background.padding_left=0 \
                    background.padding_right=0 \
                    background.padding_top=0 \
                    background.padding_bottom=0 \
                    background.color=0xff1a1a1a \
                    background.border_color=0x00000000 \
                    background.corner_radius=0 \
                    background.drawing=on \
                    label.padding_left=10 \
                    label.padding_right=10 \
                    label.padding_top=2 \
                    label.padding_bottom=2 \
                    label.font="JetBrains Mono:10.0" \
                    label.color=0xffcfcfcf \
                    label.align=left 2>/dev/null
done

while true; do
  if ! kill -0 "$PID" 2>/dev/null; then
    cleanup
  fi

  # Hard lifetime cap: bail out cleanly if we've run absurdly long. Guards
  # against orphaned workers tailing a stale log or surviving PID reuse
  # when the parent gradle.sh died and won't reap us.
  if (( $(date +%s) - WORKER_START > MAX_LIFETIME )); then
    cleanup
  fi

  sleep "$POLL_INTERVAL"

  # Build-state probe: single-pass scan of the log for the latest marker.
  state=$(awk -v S="$START_MARKER" -v F="$FINISH_MARKER" -v I="$IDLE_MARKER" '
    $0 ~ S { lastStart = NR }
    $0 ~ F { lastFinish = NR }
    $0 ~ I { lastIdle = NR }
    END {
      last = lastStart; st = "started"
      if (lastFinish > last) { last = lastFinish; st = "finished" }
      if (lastIdle   > last) { last = lastIdle;   st = "idle" }
      if (last == 0)         { st = "unknown" }
      print st
    }
  ' "$log_file" 2>/dev/null)

  case "$state" in
    "finished"|"idle") cleanup ;;
  esac

  # Stream the last N log lines, wrapped to LINE_WIDTH columns, into the
  # 15 row items. Pad missing rows to keep popup stable.
  preview=$(tail -n "$PREVIEW_LINES" "$log_file" 2>/dev/null | fold -w "$LINE_WIDTH")
  if [[ -z "$preview" ]]; then
    preview="(no build output yet)"
  fi

  # Split preview on newlines into an array.
  local rows=("${(f)preview}")
  local i=0
  for (( i = 0; i < PREVIEW_LINES; i++ )); do
    local line="${rows[$((i+1))]:-}"
    if [[ -n "$line" ]]; then
      # Escape backslashes so sketchybar parses the label literally.
      line="${line//\\/\\\\}"
      sketchybar --set "${POPUP_PREFIX}.${i}" drawing=on label="$line" 2>/dev/null
    else
      sketchybar --set "${POPUP_PREFIX}.${i}" drawing=off 2>/dev/null
    fi
  done
done
