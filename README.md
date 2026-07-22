# SketchyBar + Google Workspace Calendar Popup

A highly customizable macOS status bar configuration for **SketchyBar** that adds a **calendar popup** to the clock item, showing the next upcoming Google Calendar events with relative times. It also includes a polished media player indicator, keyboard layout switcher, volume mute toggle, battery/WiFi indicators, and AeroSpace workspace support.

---

## Features

### ⏰ Calendar Popup (Clock Item)
- **Click to toggle** a popup showing up to **10 upcoming events** from Google Calendar.
- **Relative time display** – events are shown as `in X min`, `in X h`, `in X d`.
- **Recurring events deduplicated** – for events with the same name, only the **soonest (next) occurrence** is shown.
- **Auto‑refresh** every 5 minutes (configurable via `update_freq`).
- Supports all timezone formats (`+HH:MM`, `Z` UTC) and all‑day events.
- **Hover effect** – background color changes on mouse enter/exit.

#### Requirements
- [`gws` CLI](https://github.com/googleworkspace/cli) installed and authenticated (`gws auth login --scopes calendar`).
- [`jq`](https://stedolan.github.io/jq/) for JSON parsing.
- Google Calendar API enabled in your GCP project.

#### Customization
| Setting | Default | Description |
|---------|---------|-------------|
| `popup.width` | `600` | Width of the popup window (px). Increase if text is truncated. |
| `popup.align` | `center` | Popup alignment relative to the clock item. |
| `update_freq` | `300` | How often (seconds) to refresh the event list in the background. |
| `clock_event_*` width/label.width | `600/580` | Item width and label width for each popup row. |

To change the number of displayed events, adjust `.[0:10]` in the `jq` query inside `plugins/clock.sh`.  
To change the time window (e.g., only next 7 days), replace `--days 30` with `--today` or `--week`.

---

### ▶️ Media Player
- Shows the currently playing track (title, artist, app name) using `nowplaying-cli`.
- Displays ▶ (playing) or ⏸ (paused) icon.
- Auto‑hides when nothing is playing.
- **Click to toggle play/pause**.
- Previous/Next track buttons (separate items: `media_prev`, `media_next`).

#### Requirements
- [`nowplaying-cli`](https://github.com/ procurios/nowplaying-cli) in your `$PATH`.

#### Customization
- Icon padding, label padding, and max label length (50 chars) can be adjusted in `sketchybarrc` and `plugins/media.sh`.

---

### ⌨️ Keyboard Layout Switcher
- Displays the **currently active keyboard layout** (e.g., "U.S.", "Russian").
- **Optimistic UI update** – the label changes immediately on click **before** the system actually switches, providing instant feedback.
- Cycles through layouts using `Ctrl+Space`.

#### Customization
- `update_freq=5` – how often (seconds) to poll the current layout.
- To change the shortcut, edit the `osascript` line in `plugins/kb_layout.sh`.

---

### 🔊 Volume Mute Toggle
- Shows "Muted" or "Vol: X%" label.
- **Click to mute/unmute** via AppleScript.
- Hover effect with background color change.

---

### 🔋 Battery & WiFi Indicators
- **Battery** – shows charge level (e.g., "++ 85%" when charging, "-- 85%" when on battery).
- **WiFi** – click opens macOS Network Preferences (`x-apple.systempreferences:...`).

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
│   ├── clock.sh          # Clock item + calendar popup logic
│   ├── volume.sh         # Volume mute/unmute toggle
│   ├── kb_layout.sh      # Keyboard layout switcher with optimistic UI
│   ├── media.sh          # Media player display
│   ├── media_next.sh     # Next track button
│   ├── media_prev.sh     # Previous track button
│   ├── battery.sh        # Battery indicator
│   ├── wifi.sh           # WiFi indicator
│   ├── aerospace.sh      # AeroSpace workspace handler
│   └── space.sh          # (AeroSpace space item)
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

---

## License

MIT License – see [LICENSE](LICENSE) for details.