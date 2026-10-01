# Screen Reader

A small macOS menu bar app that reads aloud the text you select in any application — fully offline.

## Features

- Reads aloud selected text from any app that allows text selection.
- Global hotkey (default **⌥⇧S**, configurable): press to read, press again to stop.
- Menu bar controls: Read Selection, Pause/Resume, Stop, Speed.
- Speeds: 0.5x, 1x, 1.5x, 2x, 2.5x.
- Detects the language of the text and picks a matching voice; per-language voice overrides.
- Uses the voices installed on your Mac. No internet connection needed.
- Never stores or transmits the text it reads.

## Requirements

- macOS 14 Sonoma or later
- To build: Xcode 16.3 or later (Swift 6.1+ toolchain)

## Install

1. Download `ScreenReader-<version>.dmg`, open it, drag **Screen Reader** to Applications.
2. The app is not notarized yet, so macOS blocks the first launch:
   - **macOS 14:** right-click the app → **Open** → **Open**.
   - **macOS 15 and later:** open the app once (it will be blocked), then go to System Settings → Privacy & Security, scroll down and click **Open Anyway**.
3. Grant **Accessibility** access when asked (System Settings → Privacy & Security → Accessibility). It is needed to read other apps' selections.

## Usage

Select text anywhere and press **⌥⇧S**. Press it again to stop. Change the shortcut, speed and voices from the menu bar icon → **Settings…**.

More voices (including Enhanced/Premium quality) can be downloaded in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices.

### How selected text is captured

The app first asks the Accessibility API for the selection. Some apps (e.g. Chrome, Electron apps) don't expose it; for those the app presses ⌘C, reads the clipboard, and immediately restores your previous clipboard contents. Clipboard-history tools may still record that copy.

## Development

```bash
swift test                 # run unit tests
./scripts/build-app.sh     # build "build/Screen Reader.app" (universal, ad-hoc signed)
./scripts/make-dmg.sh      # build build/ScreenReader-<version>.dmg
open "build/Screen Reader.app"
```

After each rebuild, macOS drops the Accessibility grant because the ad-hoc signature changes. Reset it and grant again:

```bash
tccutil reset Accessibility com.buemura.ScreenReader
```

Project layout:

- `Sources/ScreenReaderCore` — all logic (speech, voices, language detection, text capture, settings), unit-tested.
- `Sources/ScreenReaderApp` — SwiftUI menu bar app and settings window.
- `Support/Info.plist`, `scripts/` — app bundle and DMG packaging.

## Roadmap

- Developer ID signing and notarization
- Windows and Linux versions

## Tech Stack

- Swift, SwiftUI, AVFoundation, NaturalLanguage, Accessibility API
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
