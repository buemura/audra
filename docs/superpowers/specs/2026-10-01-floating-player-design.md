# Screen Reader — Floating Player Design

Adds a small always-on-top player widget so reading can be controlled without the hotkey or menu bar. Builds on `2026-10-01-screen-reader-design.md`.

## Decisions

| Topic | Decision |
|---|---|
| Window | AppKit `NSPanel`, style `.nonactivatingPanel` + `.borderless`, level `.floating`, collection behavior `.canJoinAllSpaces` + `.fullScreenAuxiliary`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`. Hosts a SwiftUI view via `NSHostingView`. Non-activating is required: clicking the panel must not make Screen Reader frontmost, otherwise "read current selection" would read our own window. |
| Visibility | Shown when speech state leaves `.idle`. Hidden 3 s after it returns to `.idle` (cancelled if reading starts again in that window). Menu bar toggle **Show Player Always** (persisted) keeps it visible while idle. Show/hide fades (~0.2 s). |
| Position | Draggable by its background (`isMovableByWindowBackground`). Position persisted with `setFrameAutosaveName`. First launch: bottom-right of the main screen's visible frame, 24 pt inset. |
| Look | ~240×120 pt card, corner radius 20 pt, solid grey that adapts to light/dark (no glass/blur), soft shadow. SF Symbols for all icons. |
| Layout | Header row: speaker icon in a rounded square · title (1 line, truncated) and subtitle · small stop button (`stop.fill`) top-right. Controls row, centered: slower (`backward.fill`), play/pause (`play.fill` / `pause.fill`, larger), faster (`forward.fill`). |
| Play/pause | Idle → read current selection (same path as the "Read Selection" menu item, including the permission check and the beep when nothing is selected). Speaking → pause. Paused → resume. Icon shows `pause.fill` while speaking, `play.fill` otherwise. |
| Slower / faster | Step `settings.speed` to the previous/next `SpeechSpeed` case. Disabled at 0.5x / 2.5x. Speech in progress picks up the new speed through the existing `settings.$speed` → `changeRate` subscription. Tooltips: "Slower" / "Faster". |
| Stop | Stops speech. Disabled while idle. |
| Title | The text being read (or last read this session), whitespace collapsed to single spaces. Placeholder when nothing was read yet: "Select text and press play". Kept in memory only — never persisted. |
| Subtitle | `"<speed> · <voice>"`, e.g. `1.5x · Luciana (pt-BR)`. Voice = name and language of the voice used for the current/last reading; `System voice` when the voice ID is nil or not installed. Before any reading: speed only. Speed always reflects the current setting. |

## Components

### ScreenReaderCore (unit-tested, no AppKit)

- **`SpeechSpeed`**: `slower: SpeechSpeed?` and `faster: SpeechSpeed?` — adjacent case in `allCases` order, nil at the ends.
- **`SpeechController`**: new `@Published public private(set) var currentText: String?` and `currentVoiceID: String?`, set by `speak(...)` to the original text and voice. Not changed by `changeRate` (which internally trims the remaining text) or by `stop`/finishing.
- **`SettingsStore`**: new `@Published public var alwaysShowPlayer: Bool`, key `alwaysShowPlayer`, default `false`.
- **`PlayerViewModel`** (`@MainActor`, `ObservableObject`): constructed with `SpeechController`, `SettingsStore`, `voices: () -> [VoiceInfo]`, and `readSelection: () async -> Void`. Re-publishes when either source object changes. Exposes:
  - `isPlaying: Bool` (state == `.speaking`) — drives the play/pause icon.
  - `canStop`, `canGoSlower`, `canGoFaster: Bool`.
  - `title: String`, `subtitle: String` as specified above.
  - `shouldBeVisible: Bool` — `state != .idle || settings.alwaysShowPlayer`. (The 3 s hide delay is the panel controller's job, not the model's.)
  - Actions: `playPause() async`, `slower()`, `faster()`, `stop()`.

### ScreenReaderApp

- **`PlayerView`** (SwiftUI): renders `PlayerViewModel`; no logic beyond layout and calling actions.
- **`PlayerPanelController`**: owns the `NSPanel`, observes `PlayerViewModel.shouldBeVisible`, applies the 3 s hide delay and fades, restores/saves position.
- **`AppModel`**: creates `PlayerViewModel` (with `readSelection: { await self.readSelection() }`) and `PlayerPanelController`.
- **`MenuBarContent`**: adds a `Toggle("Show Player Always", isOn: $settings.alwaysShowPlayer)` below the speed picker.

## Data flow

```
hotkey / menu / player ▶ ──► AppModel.readSelection ──► ReadSelectionCoordinator ──► SpeechController.speak
player ◀◀ / ▶▶ ──► settings.speed ──(existing subscription)──► SpeechController.changeRate
SpeechController.state + currentText/VoiceID, settings ──► PlayerViewModel ──► PlayerView
PlayerViewModel.shouldBeVisible ──► PlayerPanelController (delay + fade) ──► NSPanel
```

## Error handling

- No Accessibility permission when ▶ is pressed idle: same as the menu item — system prompt, polling, no speech.
- Nothing selected: system beep (existing `onNoText`).
- Repeated ▶ presses during capture: ignored by the coordinator's existing `isCapturing` guard.

## Testing

- Unit tests (TDD): `SpeechSpeed.slower/faster` at ends and middle; `SpeechController.currentText/currentVoiceID` set by `speak`, unchanged by `changeRate`/`stop`/finish; `SettingsStore.alwaysShowPlayer` default and persistence; `PlayerViewModel` — every action in every state, enabled flags, title/subtitle (placeholder, whitespace collapsing, voice found, nil/unknown voice), `shouldBeVisible`.
- Manual checks on the built app:
  1. Panel appears on hotkey read, hides ~3 s after stop; stays when "Show Player Always" is on.
  2. Stays above other apps, on every Space, and over a full-screen app.
  3. Select text in Safari and in Chrome, click ▶ on the panel: the selection is read and the source app stays frontmost.
  4. First click on any panel button acts immediately (no extra click to focus).
  5. ◀◀/▶▶ change speed audibly mid-sentence; disabled at the ends; subtitle updates.
  6. Dragged position survives relaunch.
  7. Light and dark appearance both readable.

## Out of scope

Glass/blur styling, progress bar, artwork, player hotkey, resizing, skip forward/back within the text.
