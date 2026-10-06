# Screen Reader

A small macOS menu bar app that reads aloud the text you select in any application, with natural-sounding voices that run on your Mac.

## Features

- Reads aloud selected text from any app that allows text selection.
- Global hotkey (default **⌥⇧S**, configurable): press to read, press again to stop.
- Menu bar controls: Read Selection, Pause/Resume, Stop, Speed.
- Floating player that stays on top of other apps while reading: play/pause, slower, faster and stop. It hides itself a few seconds after reading stops; turn on **Show Player Always** in the menu bar to keep it visible. Drag it anywhere — it remembers its position.
- Speeds: 0.5x, 1x, 1.5x, 2x, 2.5x.
- Detects the language of the text and picks a matching voice; per-language voice overrides.
- Natural neural voices (Kokoro) for English, Portuguese (Brazil), Spanish, French, Italian, Hindi, Japanese and Chinese (beta), generated on your Mac. Other languages use the voices installed on your Mac.
- Never stores or transmits the text it reads. The only network access is a one-time download of the natural voice model (about 190 MB) on first launch.

## Requirements

- macOS 15 Sequoia or later on Apple Silicon
- To build: Xcode 26 or later (Swift 6.2+) with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`)

## Install

1. Download `ScreenReader-<version>.dmg`, open it, drag **Screen Reader** to Applications.
2. The app is not notarized yet, so macOS blocks the first launch:
   - Open the app once (it will be blocked), then go to System Settings → Privacy & Security, scroll down and click **Open Anyway**.
3. Grant **Accessibility** access when asked (System Settings → Privacy & Security → Accessibility). It is needed to read other apps' selections.

## Usage

Select text anywhere and press **⌥⇧S**. Press it again to stop. Change the shortcut, speed and voices from the menu bar icon → **Settings…**.

You can also control reading from the floating player: ▶ reads the current selection (or pauses/resumes), ◀◀ / ▶▶ change the speed, ■ stops.

Natural voices download automatically the first time the app runs (progress shows in the menu bar menu and in Settings → General). Until then, and for languages they don't cover, the app uses the voices installed on your Mac — more of those (including Enhanced/Premium quality) can be downloaded in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices. To free the disk space, use **Remove** next to Natural voices in Settings → General.

### How selected text is captured

The app first asks the Accessibility API for the selection. Some apps (e.g. Chrome, Electron apps) don't expose it; for those the app presses ⌘C, reads the clipboard, and immediately restores your previous clipboard contents. Clipboard-history tools may still record that copy.

## Development

```bash
make run                   # build, reset the Accessibility grant and open the app
make test                  # run all tests (xcodebuild; ONLY=Target/TestClass for a subset)
swift test --filter ScreenReaderCoreTests   # fast: core logic only
./scripts/build-app.sh     # build "build/Screen Reader.app" (Apple Silicon, ad-hoc signed)
./scripts/make-dmg.sh      # build build/ScreenReader-<version>.dmg
open "build/Screen Reader.app"
```

After each rebuild, macOS drops the Accessibility grant because the ad-hoc signature changes. Reset it and grant again:

```bash
tccutil reset Accessibility com.buemura.ScreenReader
```

Project layout:

- `Sources/ScreenReaderCore` — all logic (speech, voices, language detection, text capture, settings), unit-tested.
- `Sources/ScreenReaderKokoro` — the Kokoro engine (MLX) and the English/eSpeak phonemizers.
- `Packages/` — vendored KokoroSwift (patched) and eSpeak NG; see their `VENDORED.md`.
- `scripts/prepare-kokoro-assets.py` — builds the model files published at https://github.com/buemura/screen-reader-models/releases.
- `Sources/ScreenReaderApp` — SwiftUI menu bar app and settings window.
- `Support/Info.plist`, `scripts/` — app bundle and DMG packaging.

## Roadmap

- Developer ID signing and notarization
- Windows and Linux versions

## Tech Stack

- Swift, SwiftUI, AVFoundation, NaturalLanguage, Accessibility API
- [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) on [MLX Swift](https://github.com/ml-explore/mlx-swift) via [KokoroSwift](https://github.com/mlalma/kokoro-ios)
- [MisakiSwift](https://github.com/mlalma/MisakiSwift) and [eSpeak NG](https://github.com/espeak-ng/espeak-ng) for pronunciation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

## License

GPL-3.0 (see `LICENSE`). Third-party components are listed in `THIRD_PARTY_NOTICES.md`.
