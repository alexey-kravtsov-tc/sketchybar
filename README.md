# SketchyBar + Google Workspace Calendar Popup

A highly customizable macOS status bar configuration for **SketchyBar** that adds a **calendar popup** to the clock item, showing the next upcoming Google Calendar events with relative times. It also includes a polished media player indicator, keyboard layout switcher, volume/mic controls with device switchers, battery/WiFi indicators, and AeroSpace workspace support.

---

## Architecture: synchronous shell plugins, click-only popups

Every plugin is a plain POSIX shell script, run synchronously by sketchybar. There are **no background daemons, no timers, no hover-based popups, and no auto-dismiss animations** — those previously leaked processes and froze the bar under rapid hover/unhover. Popups open on a **click**, close on a **click**, or close automatically when a popup row is selected.

The stateful controls — **volume + audio output** and **mic input + mic level** — cache their device list to `/tmp/sketchybar_*_devices.txt` and current-device file to `/tmp/sketchybar_*_current.txt` so the popup renders instantly; the first fetch calls `SwitchAudioSource` synchronously and typically completes well under a second.

---

## Features

### ⏰ Calendar Popup (Clock Item)
- **Click to toggle** a popup showing up to **10 upcoming events** from Google Calendar.
- **Relative time display** – events are shown as `in X min`, `in X h`, `in X d`.
- **Recurring events deduplicated** – for events with the same name, only the **soonest (next) occurrence** is shown.
- **Auto‑refresh** every 60 s (configurable via `update_freq=60`).
- Supports all timezone formats (`+HH:MM`, `Z` UTC) and all‑day events.

#### Requirements
- [`gws` CLI](https://github.com/googleworkspace/cli) installed and authenticated (`gws auth login --scopes calendar`).
- [`jq`](https://stedolan.github.io/jq/) for JSON parsing.
- Google Calendar API enabled in your GCP project.

#### Customization
| Setting | Default | Description |
|---------|---------|-------------|
| `popup.width` | `600` | Width of the popup window (px). Increase if text is truncated. |
| `popup.align` | `center` | Popup alignment relative to the clock item. |
| `update_freq` | `60` | How often (seconds) to refresh the event list in the background. |
| `clock_event_*` width/label.width | `600/580` | Item width and label width for each popup row. |

To change the number of displayed events, adjust `.[0:10]` in the `jq` query inside `plugins/clock.sh`.  
To change the time window (e.g., only next 7 days), replace `--days 30` with `--today` or `--week`.

---

### ▶️ Media Player
- Shows the currently playing track (title, artist, app name) using `nowplaying-cli`.
- Displays ▶ (playing) or ⏸ (paused) icon.
- Auto‑hides when nothing is playing.
- **Click the media item to toggle the popup panel** (no hover).
- The popup contains three rows: previous / play‑pause / next. Each row uses an inline `click_script` to skip / toggle / play, then refreshes the popup content.

#### Requirements
- [`nowplaying-cli`](https://github.com/procurios/nowplaying-cli) in your `$PATH`.

#### Customization
- Icon padding, label padding, and max label length (50 chars) can be adjusted in `sketchybarrc` and `plugins/media.sh`.

---

### ⌨️ Keyboard Layout Switcher
- Displays the **currently active keyboard layout** (e.g., "U.S.", "Russian").
- **Optimistic UI update** – the label changes immediately on click **before** the system actually switches, providing instant feedback.
- Click cycles through layouts using `Ctrl+Space`.
- No popup, no hover.

#### Customization
- `update_freq=5` – how often (seconds) to poll the current layout.
- To change the shortcut, edit the `osascript` line in `plugins/kb_layout.sh`.

---

### 🔊 Volume + Audio Output (click-only)
- **State 1 (default)**: bar shows text `{output} >> {volume}%` (popup hidden, slider hidden).
- **State 2 (click the text item)**: the label is blanked, the slider becomes visible, and a popup lists all available output devices (`SwitchAudioSource -a -t output`) with the current one marked (● + bold).
- Click the text item again → collapse back to State 1.
- **Click a device row → switches the output device (`SwitchAudioSource -s …`) and collapses back to State 1** so the new output device shows in the bar label.
- Drag the slider → updates the system volume (`osascript set volume output volume N`) and **keeps State 2 open** so the user can see the slider fill.

---

### 🎤 Mic Input + Level (click-only)
- Symmetric to the volume control: State 1 shows `{level}% << {input source}`.
- Click the text item → blank label, mic slider visible, popup lists all input devices with the current one marked.
- Click a device row → switch and collapse to State 1.
- Drag the mic slider → updates `set volume input volume N`, stays expanded.

---

### 🔋 Battery & WiFi Indicators
- **Battery** – shows charge level (e.g., `++ 85%` when charging, `-- 85%` when on battery). No interaction.
- **WiFi** – click opens the macOS Network System Settings pane (`x-apple.systempreferences:com.apple.preference.network`). Routine just renders a status label: `WiFi` (connected), `WiFi: off` (powered off), or `WiFi: disconnected`.

---

### 🚀 AeroSpace Workspace Handler (Invisible)
- Listens to `aerospace_workspace_change` events.
- Calls `$CONFIG_DIR/plugins/aerospace.sh` on workspace changes (useful for per‑workspace sketchybar rules).

---

## Installation

### Prerequisites
```bash
brew install sketchybar jq
# gws CLI (choose one)
brew install googleworkspace-cli
# or: npm install -g @googleworkspace/cli
# audio device-switching helper:
brew install switchaudio-source
# media now-playing helper:
brew install nowplaying-cli
```

### Setup
1. **Authenticate gws**:
   ```bash
   gws auth login --scopes calendar
   ```
2. **Link the config**:
   ```bash
   ln -sf /path/to/this/repo/sketchybarrc ~/.config/sketchybar/sketchybarrc
   ```
3. **Restart SketchyBar**:
   ```bash
   killall sketchybar; sketchybar &
   ```

---

## File Structure

```
.
├── sketchybarrc          # Main SketchyBar configuration
├── plugins/
│   ├── volume.sh          # Volume + output-device popup (click-only)
│   ├── mic_input.sh       # Mic level + input-device popup (click-only)
│   ├── media.sh           # Now-playing widget + popup panel (click-only)
│   ├── wifi.sh            # WiFi status label (click → Network Settings)
│   ├── clock.sh           # Clock item + calendar popup (click-only, synchronous)
│   ├── kb_layout.sh       # Keyboard layout switcher (no popup, no timers)
│   ├── battery.sh         # Battery indicator (no timers)
│   ├── media_prev.sh      # Previous track button (no timers)
│   ├── media_next.sh      # Next track button (no timers)
│   ├── aerospace.sh       # AeroSpace workspace handler (no timers)
│   ├── space.sh           # AeroSpace space item
│   └── gradle/            # Gradle daemon monitor (has its own worker reap + 7200s cap)
└── README.md
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No events in popup | Run `gws calendar +agenda` manually to verify authentication and Calendar API access. |
| Text is truncated | Increase `popup.width` in `sketchybarrc` (e.g., to `800`) and the corresponding `width`/`label.width` of `clock_event_*` items. |
| Media player not showing | Ensure `nowplaying-cli` is installed and returns JSON when music is playing. |
| Keyboard layout not switching | Verify `System Events` permission is granted to Terminal/Script Editor in System Preferences → Privacy & Security → Accessibility. |
| gws not found | Make sure `$PATH` includes the Homebrew bin directory, or add `eval "$(brew shellenv)"` to your shell rc. |
| Volume/mic popup not opening | Ensure `SwitchAudioSource -a -t output` returns the device list. The first click runs `SwitchAudioSource` synchronously; if your machine is slow the first click may take ~1 s. |
| Orphaned devices listed | Delete the `/tmp/sketchybar_*.txt` cache files; the next routine refresh rebuilds them. |

---

## License

MIT License – see [LICENSE](LICENSE) for details.
