# Screen Reader — v1 Design

Source requirements: `README.md`. This document records the decisions made on top of it.

## Product

A macOS menu bar app that reads aloud the text currently selected in any application, fully offline.

### Decisions

| Topic | Decision |
|---|---|
| App shape | Menu bar only (no Dock icon, `LSUIElement`). SF Symbol icon; filled while speaking. |
| Trigger | Global hotkey (default ⌥⇧S, user-configurable) **and** menu bar items. |
| Hotkey semantics | Idle → read current selection. Speaking or paused → stop. |
| Menu items | Accessibility warning (only when permission missing), Read Selection, Pause/Resume, Stop, Speed submenu, Settings…, Quit. |
| Text capture | Accessibility API (`kAXSelectedTextAttribute` of the focused element) first. If that yields nothing: snapshot clipboard → synthesize ⌘C → wait ≤300 ms for clipboard change → read string → restore clipboard. If the clipboard never changes, it is left untouched. |
| Nothing selected | System beep, no speech. |
| Speech engine | `AVSpeechSynthesizer` with installed system voices (offline). |
| Speeds | 0.5x, 1x, 1.5x, 2x, 2.5x. Mapped to `AVSpeechUtterance.rate` via a tuned table (1x = `AVSpeechUtteranceDefaultSpeechRate`). |
| Languages | On-device detection (`NLLanguageRecognizer`, confidence ≥ 0.5). Voice choice: per-language override → default voice if it speaks that language → best-quality installed voice for that language → default voice → system default. Auto-detect can be turned off (then: default voice always). |
| Settings | Settings window: General (hotkey recorder, speed, default voice, auto-detect toggle) and Voices (per-language voice override). Persisted in `UserDefaults`. |
| Privacy | No network access. Selected text is never logged, persisted or transmitted. Clipboard restored after the ⌘C fallback. |
| Permissions | Accessibility. Prompt on launch if missing; menu shows a warning item linking to System Settings; app polls until granted. |
| Platform | macOS 14+. Universal binary (arm64 + x86_64). |
| Build | Swift Package (`swift build` / `swift test`); `scripts/build-app.sh` assembles an ad-hoc-signed `.app`; `scripts/make-dmg.sh` wraps it in a DMG. Developer ID signing + notarization is out of scope for v1 (documented as a later step). |
| Dependencies | `KeyboardShortcuts` (sindresorhus) for the global hotkey and recorder UI — app target only. |

### Out of scope for v1

Windows/Linux, auto-read on selection, highlighting spoken words, Developer ID signing/notarization, auto-update, launch at login, app icon artwork.

### Known limitations

- The ⌘C fallback uses the ANSI "C" key code; non-QWERTY layouts that remap ⌘-shortcuts by position may not copy.
- Clipboard-history apps may record the text copied by the ⌘C fallback (the copy is performed by the source app).
- The restored clipboard is marked `org.nspasteboard.TransientType`; clipboard tools that don't honour that marker may still log the restore.
- Ad-hoc signing means the Accessibility grant must be re-done after every rebuild, and Gatekeeper will warn on first open of a downloaded DMG.
