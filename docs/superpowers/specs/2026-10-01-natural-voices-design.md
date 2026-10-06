# Natural Voices (Kokoro) — Design

Goal: replace the robotic-sounding system voices with natural neural voices, primarily for English, Portuguese (Brazil), Spanish and Japanese, and for every other language Kokoro supports. Speech stays on-device; the text being read never leaves the Mac.

## Background

- The app speaks through `AVSpeechSynthesizer`. `VoiceSelector` already prefers the best installed voice, but most Macs (including the developer's) only have compact / Eloquence voices installed, which sound robotic.
- A spike (2026-10-01, throwaway code) confirmed that Kokoro-82M runs from Swift via MLX (KokoroSwift) on an M1 Pro at 5.5–8x real time for en, pt-BR, es and ja, with 0.5 s model load. The listener judged it clearly better than the current voices.

## Decisions

| Topic | Decision |
|---|---|
| Engine | Kokoro-82M v1.0 via KokoroSwift (MLX), vendored as a local package with two patches: phoneme input, and tokenizing phonemes per Unicode scalar (upstream looks up whole grapheme clusters, which silently drops nasal vowels such as `ɐ̃`). |
| Kokoro languages | en-US, en-GB, pt-BR, es, fr, it, hi, ja, zh (zh marked beta). All other languages keep system voices. |
| Text → phonemes | en: MisakiSwift. es/pt-BR/fr/it/hi: eSpeak NG 1.52.0. ja: macOS `CFStringTokenizer` readings + rules + misaki kana table. zh: macOS `CFStringTokenizer` word pinyin + misaki pinyin rules. |
| License | eSpeak NG is GPL-3.0, so the project becomes GPL-3.0 (add `LICENSE`, `THIRD_PARTY_NOTICES.md`). |
| Model delivery | fp16 weights (`kokoro-v1_0-fp16.safetensors`, 164 MB; judged indistinguishable from fp32 by ear) + `voices.npz` (27 MB). Downloaded automatically in the background on first launch from release `kokoro-model-v1` of the public repo `buemura/screen-reader-models` (the app repo is private); SHA-256 pinned in code. System voices are used until it is ready. Removable from Settings. |
| Platform | macOS 15+, Apple Silicon only (was macOS 14+, universal). |
| Voice UX | Kokoro voices appear in the existing voice pickers with a new `.natural` quality ranked above Premium; with no override, a supported language gets its default Kokoro voice. |
| Live changes | Speed/voice changes mid-reading restart from the start of the current sentence (was: current word). |
| Memory | Model is loaded on first Kokoro reading and unloaded after 10 minutes without Kokoro speech. |

## Architecture

```
ReadSelectionCoordinator ─▶ VoiceSelector (system + Kokoro voices)
          │
          ▼
   SpeechController
          │
          ▼
   RoutingSynthesizer ──"kokoro.*"──▶ KokoroSynthesizer
          │                             ├─ SentenceSplitter
          └─ other ─▶ AVSpeechSynthesizerAdapter    ├─ Phonemizer (per language)
                                        ├─ KokoroEngine (MLX, background)
                                        └─ AudioOutput (AVAudioEngine)
   KokoroModelStore ── download / verify / remove, publishes state
```

Pure logic and protocols live in `ScreenReaderCore` (synthesizers, splitter, catalog, model store, Japanese/Chinese phonemizers). Code that links MLX, MisakiSwift or eSpeak NG lives in a new `ScreenReaderKokoro` target (`MLXKokoroEngine`, `EnglishPhonemizer`, `ESpeakPhonemizer`, `KokoroPhonemizers`), so Core stays fast to build and test. Each unit depends on protocols so it can be tested with fakes.

### `SpeechSynthesizing` interface change

`speak(_ text: String, voiceID: String?, rate: Float)` becomes `speak(_ text: String, voiceID: String?, speed: SpeechSpeed)`. `AVSpeechSynthesizerAdapter` maps `speed.utteranceRate` internally; Kokoro passes `speed.rawValue` as its native speed multiplier. `SpeechController` stores a `SpeechSpeed` instead of a `Float`; `changeRate` becomes `changeSpeed`. Its restart-from-progress logic is otherwise unchanged.

### `RoutingSynthesizer: SpeechSynthesizing`

Holds a system synthesizer and a Kokoro synthesizer. `speak` stops the currently active engine, picks the engine by voice ID prefix (`kokoro.` → Kokoro, anything else incl. nil → system), and forwards. `pause`/`resume`/`stop` go to the active engine. Each engine's `onFinish`/`onProgress` is forwarded only while that engine is active.

### `KokoroSynthesizer: SpeechSynthesizing`

- `speak`: splits text with `SentenceSplitter`, then a background task phonemizes and synthesizes sentence by sentence, keeping at most 2 sentences buffered ahead of playback. Each buffer is scheduled on `AudioOutput`.
- When a sentence's buffer starts playing → `onProgress(sentence UTF-16 offset)`. When the last buffer finishes → `onFinish()`.
- `pause`/`resume` → pause/play the output; synthesis continues filling the look-ahead.
- `stop` → cancel the task, clear the output. A generation counter discards results from cancelled readings; `onFinish` is not called after `stop` (matches the protocol contract).
- Failure handling: a sentence whose phonemization or synthesis throws is skipped (logged without its text). If the engine cannot load, the synthesizer reports a fallback through `onEngineFailure`, and `RoutingSynthesizer` continues the remaining text from the current sentence with the system voice selected for that language (passed in via a closure).

### `SentenceSplitter`

Splits with `NLTokenizer(unit: .sentence)` and returns `(text, utf16Offset)` pairs. A sentence whose phonemes would exceed Kokoro's 510-token limit is split again at clause punctuation (`,;:、，；：`), then at word boundaries. Splitting on phoneme length happens inside `KokoroSynthesizer` after phonemization (re-splitting the source text and re-phonemizing the parts).

### `Phonemizer`

```swift
protocol Phonemizer { func phonemize(_ text: String) throws -> String }
```

Shared pre-step for all: normalize whitespace, drop characters Kokoro cannot voice (emoji, unassigned symbols). `PhonemizerRegistry` maps a Kokoro language (`en-US`, `en-GB`, `pt-BR`, `es`, `fr`, `it`, `hi`, `ja`, `zh`) to its phonemizer.

| Language | Implementation |
|---|---|
| en-US, en-GB | `EnglishPhonemizer` — MisakiSwift `EnglishG2P(british:)`. |
| es, pt-BR, fr, it, hi | `ESpeakPhonemizer(voice:)` — eSpeak NG phoneme output (IPA), then the same post-processing misaki's `EspeakG2P` applies for Kokoro (symbol replacements, tie removal, language-specific fixes). eSpeak handles numbers/abbreviations. |
| ja | `JapanesePhonemizer` — (1) tokenize with `CFStringTokenizer` (ja locale), reading = Latin transcription → hiragana; katakana tokens keep their surface form so ー survives; (2) fix-ups: standalone particle は→わ, へ→え, を→お; (3) numbers via a `JapaneseNumberReader` (digits → kana, counters 年/月/日/時/分/円/人/つ, special readings e.g. 1日→ついたち, 2日→ふつか, 20日→はつか, 1人→ひとり); (4) kana → phonemes with misaki's `ja` kana table ported to Swift. No pitch-accent marks. |
| zh (beta) | `ChinesePhonemizer` — digits → Chinese numerals (4-digit years digit by digit), words and context-aware tone-marked pinyin from `CFStringTokenizer` (zh-Hans), pinyin split into one syllable per Han character, pinyin → phonemes with misaki's `zh` rules ported to Swift. Falls back to per-character `kCFStringTransformMandarinLatin` when a word's pinyin can't be split. |

If a phonemizer throws for a sentence and the language is eSpeak-capable (eSpeak covers ja/zh too, at lower quality), that sentence falls back to eSpeak; otherwise it is skipped.

### `KokoroEngine`

Protocol `synthesize(phonemes: String, voice: KokoroVoice, speed: Float) throws -> [Float]` (24 kHz mono). The real implementation wraps the vendored KokoroSwift (`generateAudio(voice:phonemes:speed:)`), loads `voices.npz` lazily per voice, and runs on a dedicated background actor. Loading is lazy; an idle timer unloads it after 10 minutes without Kokoro speech.

### `AudioOutput`

Protocol over `AVAudioEngine` + `AVAudioPlayerNode`: `schedule(samples:onStart:onEnd:)`, `pause()`, `play()`, `stop()`. Lets `KokoroSynthesizer` be tested without audio hardware. `onStart` is derived from the completion of the previous buffer (or immediately for the first).

### `KokoroVoiceCatalog`

Static list of Kokoro v1.0 voices → `VoiceInfo(id: "kokoro.<name>", name:, language:, quality: .natural)`. Default per language (first in its list):

| Language | Voices (default first) |
|---|---|
| en-US | af_heart, af_bella, af_nicole, af_aoede, af_kore, af_sarah, af_nova, af_sky, af_alloy, af_jessica, af_river, am_michael, am_fenrir, am_puck, am_echo, am_eric, am_liam, am_onyx, am_adam |
| en-GB | bf_emma, bf_isabella, bf_alice, bf_lily, bm_george, bm_fable, bm_lewis, bm_daniel |
| pt-BR | pf_dora, pm_alex |
| es | ef_dora, em_alex |
| fr | ff_siwis |
| it | if_sara, im_nicola |
| hi | hf_alpha, hf_beta, hm_omega, hm_psi |
| ja | jf_alpha, jf_gongitsune, jf_nezumi, jf_tebukuro, jm_kumo |
| zh | zf_xiaobei, zf_xiaoni, zf_xiaoxiao, zf_xiaoyi, zm_yunjian, zm_yunxi, zm_yunxia, zm_yunyang |

Display names are capitalised without prefix (e.g. "Dora"), and the picker label shows "Natural": `Dora (pt-BR, Natural)`. Novelty voices (`*_santa`) are excluded.

Catalog voices are listed only when `KokoroModelStore.state == .ready`. `AppModel` combines `SystemVoices.all()` + catalog voices into the list passed to `VoiceSelector`, the pickers and `PlayerViewModel`.

### `VoiceSelector`

`VoiceInfo.Quality` gains `.natural = 4`. Existing rules are unchanged; because "best quality" now prefers `.natural`, a supported language with no override gets a Kokoro voice. Rule 3's tie-break (name A–Z) is replaced, for Kokoro voices, by catalog order so each language gets its intended default. A stale override (Kokoro voice while model not ready) is already handled: the voice is not in `availableVoices`, so selection falls through.

Note: rule 2 (default voice if it speaks the detected language) still wins over rule 3. If the user's default voice is a system voice in that language, it is used. This is intentional: an explicit choice beats the automatic upgrade.

### `KokoroModelStore`

`@MainActor ObservableObject` with `state: notDownloaded | downloading(progress: Double) | ready | failed(message)`.

- Files: `~/Library/Application Support/ScreenReader/Kokoro/kokoro-v1_0.safetensors` and `voices.npz`.
- On launch: if both files exist → `ready` (checksums verified only after download, not every launch). Otherwise start the download automatically.
- Download with `URLSession` (behind a `ModelDownloading` protocol); store resume data on failure; verify SHA-256 against constants; move into place atomically; → `ready`.
- `retry()` (from Settings), `remove()` (deletes the directory, → `notDownloaded`, does not auto-download again until next launch or retry).
- Source: GitHub Release `kokoro-model-v1` on the public repo `buemura/screen-reader-models`. URLs, sizes and checksums are constants in `KokoroModelAssets`.

## UI

- **Settings → General:** "Natural voices" row: status text (`Downloading… 42%`, `Ready (320 MB)`, `Download failed — Retry`, `Not downloaded — Download`) with Retry/Download/Remove buttons.
- **Menu bar:** while downloading, a disabled item `Downloading natural voices… 42%`.
- **Voice pickers:** Kokoro voices listed with the `Natural` label. The Voices tab footnote mentions natural voices in addition to System Settings voices.

## Build & packaging

- `Package.swift`: tools 6.0, `platforms: [.macOS(.v15)]`, Swift 5 language mode; add local packages `Packages/KokoroSwift` (mlx-swift, MisakiSwift, MLXUtilsLibrary at pinned versions) and `Packages/ESpeakNG` (the prebuilt eSpeak NG 1.52.0 `ESpeakNG.xcframework` from mlalma/eSpeakNGSwift, macOS slice only, `espeak-ng-data` pruned to the languages used).
- `scripts/build-app.sh`: arm64-only `xcodebuild` build (MLX Metal shaders require it); bundle `mlx.metallib`, the KokoroSwift resources and eSpeak data. `Makefile` and `scripts/make-dmg.sh` updated accordingly. Add `make test` running `xcodebuild test`.
- README prerequisite: Xcode + Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).
- `scripts/prepare-kokoro-assets.py` (repo-only, not shipped): downloads KokoroSwift-format weights (pinned URL + SHA-256) and the catalog voices from `hexgrad/Kokoro-82M` (pinned revision), writes `kokoro-v1_0-fp16.safetensors` and `voices.npz` byte-for-byte reproducibly, and prints sizes and SHA-256s. The maintainer uploads them to the `kokoro-model-v1` release.

## Licensing

- `LICENSE`: GPL-3.0.
- `THIRD_PARTY_NOTICES.md`: Kokoro-82M weights (Apache-2.0), KokoroSwift, MisakiSwift, MLXUtilsLibrary, MLX (MIT), eSpeak NG 1.52.0 and eSpeakNGSwift's prebuilt framework (GPL-3.0, with source links), misaki tables (Apache-2.0), pinyin-to-ipa (MIT), KeyboardShortcuts (MIT).

## Testing

TDD, unit tests in `ScreenReaderCoreTests` with fakes for `KokoroEngine`, `AudioOutput`, `ModelDownloading`:

- `RoutingSynthesizer`: routing by ID; forwarding pause/resume/stop; callbacks only from the active engine; engine switch stops the previous one; fallback continuation on Kokoro failure.
- `KokoroSynthesizer`: sentence order; look-ahead ≤ 2; progress offsets; finish after last sentence; stop mid-synthesis ignores late results; no `onFinish` after stop; failed sentence skipped.
- `SentenceSplitter`: multiple sentences, CJK punctuation, over-long sentence splitting.
- `JapanesePhonemizer` / `JapaneseNumberReader` / `ChinesePhonemizer` / `ESpeakPhonemizer` / `EnglishPhonemizer`: snapshot tests against misaki reference phonemes for a fixed sentence set; ja specifics (particles, ー, numbers, 1日/20日).
- `VoiceSelector`: `.natural` outranks Premium; catalog-order default; stale Kokoro override falls through; default system voice in the detected language still wins.
- `KokoroModelStore`: state transitions; checksum mismatch → `failed`; retry; remove; launch with files present → `ready`.
- `SpeechController`: existing tests updated for `SpeechSpeed`.

`make test` runs everything with `xcodebuild test` (MLX needs Xcode's Metal toolchain). `swift test --filter ScreenReaderCoreTests` still works for Core alone.

Manual check: in the built app, read the fixed sample sentences in all 9 language variants; check pause/resume, speed change mid-reading, stop, and first-launch download + remove.

## Docs

README: natural voices feature; requirements macOS 15 + Apple Silicon; one-time model download (~165–330 MB) and that it is the app's only network access, text is never transmitted; build prerequisites; license. The v1 spec's "no network access" privacy decision is superseded by this design.

## Out of scope

Word-level highlighting; MeCab/UniDic for Japanese; Intel and macOS 14 support; user-supplied Kokoro voices; Kokoro for languages it does not support; voice blending.
