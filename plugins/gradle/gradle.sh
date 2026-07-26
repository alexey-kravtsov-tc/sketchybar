#!/usr/bin/env zsh
# Main Gradle daemon monitor plugin for SketchyBar.
# Detects Gradle daemons (incl. those launched by Android Studio) that are
# actively running a build, and surfaces them in the bar + popup menu.

PGREP_BIN="$(command -v pgrep)"
ITEM_NAME="gradle"
WORKER_SCRIPT="$HOME/.config/sketchybar/plugins/gradle/gradle_worker.sh"
GRADLE_DAEMON_DIR="$HOME/.gradle/daemon"

# Build state markers found in daemon-<PID>.out.log.
START_MARKER='The daemon has started executing the build'
FINISH_MARKER='The daemon has finished executing the build'
IDLE_MARKER='Marking the daemon as idle'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

gradle::daemon_pids() {
  ${=PGREP_BIN} -f 'org\.gradle\.launcher\.daemon\.bootstrap\.GradleDaemon' 2>/dev/null
}

gradle::find_log_for_pid() {
  local pid="$1" version
  for version in "$GRADLE_DAEMON_DIR"/*(/N); do
    local log="$version/daemon-${pid}.out.log"
    [[ -f "$log" ]] && { echo "$log"; return; }
  done
}

# Print "busy" / "idle" by looking at the last build-boundary marker line.
gradle::log_build_state() {
  local log="$1"
  [[ -z "$log" || ! -f "$log" ]] && { echo "idle"; return; }
  local awk_prog='$0 ~ S { lastStart = NR }
$0 ~ F { lastFinish = NR }
$0 ~ I { lastIdle = NR }
END {
  last = lastStart; state = "started"
  if (lastFinish > last) { last = lastFinish; state = "finished" }
  if (lastIdle   > last) { last = lastIdle;   state = "idle" }
  if (last == 0)         { state = "unknown" }
  print state
}'
  local result="$(awk -v S="$START_MARKER" -v F="$FINISH_MARKER" -v I="$IDLE_MARKER" "$awk_prog" "$log" 2>/dev/null)"
  case "$result" in
    started)           echo "busy" ;;
    finished|idle|*)   echo "idle" ;;
  esac
}

# Print one PID line per daemon currently busy executing a build.
gradle::active_daemon_pids() {
  local pid log state
  for pid in $(gradle::daemon_pids); do
    log="$(gradle::find_log_for_pid "$pid")"
    [[ -z "$log" ]] && continue
    state="$(gradle::log_build_state "$log")"
    [[ "$state" == "busy" ]] && echo "$pid"
  done
}

gradle::render_idle() {
  sketchybar --set "$ITEM_NAME" drawing=off popup.drawing=off 2>/dev/null
}

gradle::render_active() {
  local count="$1" label
  if (( count == 1 )); then
    label="Active Gradle"
  else
    label="$count Gradle Daemons"
  fi
  sketchybar --set "$ITEM_NAME" drawing=on \
                          label="$label" 2>/dev/null
}

gradle::spawn_worker() {
  local pid="$1"
  local pidfile="/tmp/sketchybar_gradle_worker_${pid}.pid"
  # Atomic create: succeeds only if the file didn't exist. This closes the
  # race where two concurrent routine ticks spawn a second worker for the
  # same Gradle daemon PID; the loser exits 0 without forking a process.
  if ! ( set -C; echo $$ > "$pidfile" ) 2>/dev/null; then
    return
  fi
  nohup "$WORKER_SCRIPT" "$pid" >/dev/null 2>&1 &!
  # Overwrite the marker (now safely owned) with the actual worker PID.
  echo $! > "$pidfile"
}

gradle::reap_workers() {
  local keep_pids=("$@") f
  setopt local_options null_glob
  for f in /tmp/sketchybar_gradle_worker_*.pid; do
    local target_pid="${${f:t}#sketchybar_gradle_worker_}"
    target_pid="${target_pid%.pid}"
    if (( ! ${keep_pids[(I)$target_pid]} )); then
      local wpid="$(cat "$f" 2>/dev/null)"
      [[ -n "$wpid" ]] && kill "$wpid" 2>/dev/null
      rm -f "$f"
    fi
  done
}

# ---------------------------------------------------------------------------
# Event handling
# ---------------------------------------------------------------------------

case "$SENDER" in
  routine|forced|system_woke)
    active_pids=($(gradle::active_daemon_pids))
    count=${#active_pids[@]}

    if (( count == 0 )); then
      gradle::reap_workers
      gradle::render_idle
    else
      gradle::render_active "$count"
      local p
      for p in "${active_pids[@]}"; do gradle::spawn_worker "$p"; done
      gradle::reap_workers "${active_pids[@]}"
    fi
    ;;

  mouse.clicked)
    sketchybar --set "$ITEM_NAME" popup.drawing=toggle 2>/dev/null
    ;;
esac
