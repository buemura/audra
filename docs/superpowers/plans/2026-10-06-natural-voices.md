# Natural Voices (Kokoro) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the robotic system voices with on-device Kokoro-82M neural voices for en, pt-BR, es, fr, it, hi, ja and zh. All other languages, and any failure, fall back to system voices.

**Architecture:** A `RoutingSynthesizer` sits behind the existing `SpeechSynthesizing` interface. It sends `kokoro.*` voice IDs to a new `KokoroSynthesizer`: sentences → per-language phonemizer → MLX Kokoro engine → `AVAudioEngine`, with 2 sentences synthesized ahead. All other voice IDs go to the existing `AVSpeechSynthesizerAdapter`. Kokoro voices join the existing voice lists as a new `.natural` quality once `KokoroModelStore` has downloaded and verified the model. Pure logic lives in `AudraCore`; anything linking MLX, MisakiSwift or eSpeak NG lives in a new `AudraKokoro` target.

**Tech Stack:** Swift, SwiftUI, AVFoundation, NaturalLanguage, CFStringTokenizer, CryptoKit, MLX Swift 0.30.2, KokoroSwift (vendored), MisakiSwift 1.0.6, eSpeak NG 1.52.0 (prebuilt framework, vendored), XCTest.

**Spec:** `docs/superpowers/specs/2026-10-01-natural-voices-design.md`

**Dry run (2026-10-06):** Tasks 1–13, 15 and 16 were applied to a scratch copy of the repo from this plan's text. `make test` passed (169 Core tests, 9 Kokoro tests including real fp16 synthesis), and the packaged app synthesized English, Portuguese and Japanese with Kokoro. The Japanese, Chinese and eSpeak phonemizers reproduce misaki's reference outputs exactly. Task 14's publish step and Task 18's checks weren't run.

## Global Constraints

- Platform: macOS 15+, Apple Silicon (arm64) only. Build toolchain: Xcode 26 / Swift 6.2+ with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).
- Root `Package.swift` (from Task 13): `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]`. Tasks 1–12 keep the current manifest.
- Kokoro voice IDs are `"kokoro."` + the Kokoro voice name, e.g. `kokoro.pf_dora`. Any other ID (or nil) is a system voice.
- Default Kokoro voice per language (first in catalog order): en-US `af_heart`, en-GB `bf_emma`, pt-BR `pf_dora`, es `ef_dora`, fr `ff_siwis`, it `if_sara`, hi `hf_alpha`, ja `jf_alpha`, zh `zf_xiaobei`.
- Picker label for Kokoro voices: `"<Name> (<language>, Natural)"`, e.g. `Dora (pt-BR, Natural)`.
- Kokoro input limit: 510 phonemes, counted in **Unicode scalars**.
- Look-ahead: at most 3 sentence buffers queued (the one playing + 2 ahead).
- The model is unloaded after 600 seconds without Kokoro speech.
- Model files go in `~/Library/Application Support/Audra/Kokoro/`.
- Model assets (release `kokoro-model-v1` on the **public** repo `buemura/audra-models`):
  - `kokoro-v1_0-fp16.safetensors`: 163587908 bytes, sha256 `67d4b879ce0f0bc6d30169cca8dc424f192cbed5be811078d8ef7c4a34a34b1f`
  - `voices.npz`: 26645914 bytes, sha256 `9555acb689b3856bb58215b42e0ce65bcc228e1b6286df9c7d92d205e795d3dc`
- Pinned third-party sources:
  - KokoroSwift `mlalma/kokoro-ios` @ `4d6d1d8ff8cd012014180c9cd4cf0151e7682354`
  - eSpeakNGSwift `mlalma/eSpeakNGSwift` @ `a2b2fbb2efca20e1273a7399e3d578d67ca8940d` (eSpeak NG 1.52.0)
  - mlx-swift `0.30.2`, MisakiSwift `1.0.6`, MLXUtilsLibrary `0.0.6`
- Privacy: selected text is never logged, persisted or transmitted. The only network access is the model download.
- License: GPL-3.0 (because of eSpeak NG).
- Every commit message ends with a blank line and then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Test commands:
  - Tasks 1–12: `swift test --filter <TestClass>`.
  - From Task 13: `make test` (all tests) or `make test ONLY=<Target>/<TestClass>`. It uses `xcodebuild`; `swift test --filter AudraCoreTests` still works for Core alone.

## File Structure

```
Package.swift                                   (modify, Task 13)
Packages/KokoroSwift/                           (create, Task 13: vendored + patched)
Packages/ESpeakNG/                              (create, Task 13: vendored prebuilt framework)
Sources/AudraCore/
  Speech/SpeechSynthesizing.swift               (modify: speed instead of rate)
  Speech/SpeechController.swift                 (modify)
  Speech/AVSpeechSynthesizerAdapter.swift       (modify)
  Speech/RoutingSynthesizer.swift               (create)
  Speech/SentenceSplitter.swift                 (create)
  Speech/AudioOutput.swift                      (create: protocol + AVAudioEngineOutput)
  Kokoro/KokoroEngine.swift                     (create: protocol + errors)
  Kokoro/KokoroSynthesizer.swift                (create)
  Kokoro/KokoroVoiceCatalog.swift               (create: KokoroLanguage, KokoroVoice, catalog)
  Kokoro/KokoroModelStore.swift                 (create)
  Kokoro/KokoroModelAssets.swift                (create)
  Kokoro/URLSessionModelDownloader.swift        (create)
  Phonemes/Phonemizer.swift                     (create: protocol, PhonemeJoiner, FallbackPhonemizer)
  Phonemes/JapaneseNumberReader.swift           (create)
  Phonemes/JapaneseKanaTable.swift              (create)
  Phonemes/JapanesePhonemizer.swift             (create)
  Phonemes/ChineseNumberReader.swift            (create)
  Phonemes/PinyinTranscriber.swift              (create)
  Phonemes/ChinesePhonemizer.swift              (create)
  Voices/VoiceInfo.swift                        (modify: .natural, sortOrder)
  Voices/VoiceSelector.swift                    (modify: sortOrder tie-break)
  ReadSelectionCoordinator.swift                (modify: speed)
Sources/AudraKokoro/                     (create, Tasks 13, 15)
  ESpeakPhonemizer.swift
  EnglishPhonemizer.swift
  MLXKokoroEngine.swift
  KokoroPhonemizers.swift
Sources/AudraApp/
  AppModel.swift, SettingsView.swift, MenuBarContent.swift, AudraApp.swift (modify, Task 16)
Tests/AudraCoreTests/                    (new test files per task; Fakes/ extended)
Tests/AudraKokoroTests/                  (create, Tasks 13, 15)
scripts/build-app.sh, Makefile                  (modify, Task 13)
scripts/prepare-kokoro-assets.py                (create, Task 14)
Support/Info.plist                              (modify, Task 13: LSMinimumSystemVersion 15.0)
README.md, LICENSE, THIRD_PARTY_NOTICES.md      (Task 17)
```

---

### Task 1: Speed-based synthesizer interface

The synthesizer receives a `SpeechSpeed` instead of an AVSpeech rate. Kokoro needs a real speed multiplier; the system adapter keeps its tuned rate table internally.

**Files:**
- Modify: `Sources/AudraCore/Speech/SpeechSynthesizing.swift`
- Modify: `Sources/AudraCore/Speech/AVSpeechSynthesizerAdapter.swift`
- Modify: `Sources/AudraCore/Speech/SpeechController.swift`
- Modify: `Sources/AudraCore/ReadSelectionCoordinator.swift`
- Modify: `Tests/AudraCoreTests/Fakes/FakeSynthesizer.swift`
- Modify: `Tests/AudraCoreTests/SpeechControllerTests.swift`
- Modify: `Tests/AudraCoreTests/ReadSelectionCoordinatorTests.swift`
- Modify: `Tests/AudraCoreTests/PlayerViewModelTests.swift`

**Interfaces:**
- Produces: `SpeechSynthesizing.speak(_ text: String, voiceID: String?, speed: SpeechSpeed)`; `SpeechController.speak(_:voiceID:speed:)`; `SpeechController.changeSpeed(_ speed: SpeechSpeed)` (replaces `changeRate`); `FakeSynthesizer.Call.speak(text:voiceID:speed:)`. `FakeSynthesizer` becomes a non-final `class` so Task 11 can subclass it.

- [ ] **Step 1: Update the fake and the tests to the new interface**

Replace `Tests/AudraCoreTests/Fakes/FakeSynthesizer.swift` with:

```swift
@testable import AudraCore

@MainActor
class FakeSynthesizer: SpeechSynthesizing {
    enum Call: Equatable {
        case speak(text: String, voiceID: String?, speed: SpeechSpeed)
        case stop
        case pause
        case resume
    }

    var onFinish: (@MainActor () -> Void)?
    var onProgress: (@MainActor (Int) -> Void)?
    private(set) var calls: [Call] = []

    func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        calls.append(.speak(text: text, voiceID: voiceID, speed: speed))
    }

    func stop() { calls.append(.stop) }
    func pause() { calls.append(.pause) }
    func resume() { calls.append(.resume) }

    /// Simulates the current utterance ending naturally.
    func finish() { onFinish?() }

    /// Simulates the engine starting the word at `offset` (UTF-16) of the current utterance.
    func progress(to offset: Int) { onProgress?(offset) }
}
```

Then rewrite the existing tests mechanically:

```bash
sed -i '' \
  -e 's/rate: SpeechSpeed\.double\.utteranceRate/speed: .double/g' \
  -e 's/rate: SpeechSpeed\.normal\.utteranceRate/speed: .normal/g' \
  -e 's/rate: 0\.5/speed: .normal/g' \
  -e 's/rate: 0\.7/speed: .double/g' \
  -e 's/rate: 0\.6/speed: .oneAndHalf/g' \
  -e 's/changeRate(0\.7)/changeSpeed(.double)/g' \
  -e 's/changeRate(0\.6)/changeSpeed(.oneAndHalf)/g' \
  Tests/AudraCoreTests/*.swift
grep -n "rate:\|changeRate" Tests/AudraCoreTests/*.swift
```

Expected: the final `grep` prints nothing.

Append this test to `SpeechControllerTests` (before the closing brace):

```swift
    func testChangeSpeedToSameSpeedDoesNothing() {
        makeController()
        controller.speak("Hello", voiceID: "v1", speed: .normal)
        controller.changeSpeed(.normal)
        XCTAssertEqual(synthesizer.calls, [.speak(text: "Hello", voiceID: "v1", speed: .normal)])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SpeechControllerTests`
Expected: compile errors such as `extra argument 'speed' in call` and `value of type 'SpeechController' has no member 'changeSpeed'`.

- [ ] **Step 3: Implement**

In `Sources/AudraCore/Speech/SpeechSynthesizing.swift`, replace `func speak(_ text: String, voiceID: String?, rate: Float)` with:

```swift
    func speak(_ text: String, voiceID: String?, speed: SpeechSpeed)
```

In `Sources/AudraCore/Speech/AVSpeechSynthesizerAdapter.swift`, replace the `speak` method with:

```swift
    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        let utterance = AVSpeechUtterance(string: text)
        if let voiceID, let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        }
        utterance.rate = speed.utteranceRate
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }
```

In `Sources/AudraCore/Speech/SpeechController.swift`:
- replace `private var rate: Float = 0` with `private var speed: SpeechSpeed = .normal`;
- replace the `speak` method, `changeRate`, and every `synthesizer.speak(..., rate: rate)` call as follows:

```swift
    /// Speaks `text`, replacing anything currently playing.
    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        if state != .idle { synthesizer.stop() }
        currentText = text
        currentVoiceID = voiceID
        self.text = text
        self.voiceID = voiceID
        self.speed = speed
        spokenOffset = 0
        restartOnResume = false
        synthesizer.speak(text, voiceID: voiceID, speed: speed)
        state = .speaking
    }

    /// Applies a new speed to speech in progress. Engines can't change speed mid-utterance,
    /// so the rest of the text is restarted from the last reported position. While paused,
    /// the restart happens on resume.
    public func changeSpeed(_ speed: SpeechSpeed) {
        guard state != .idle, speed != self.speed else { return }
        self.speed = speed
        restartFromCurrentWord()
    }
```

In `restartFromCurrentWord()` and `resume()`, change `synthesizer.speak(remaining, voiceID: voiceID, rate: rate)` / `synthesizer.speak(text, voiceID: voiceID, rate: rate)` to pass `speed: speed`. In the `changeVoice` doc comment, replace "like `changeRate`" with "like `changeSpeed`". Also update the comment on `spokenOffset` to: `/// UTF-16 offset in \`text\` of the last position the engine reported (a word for system voices, a sentence for Kokoro).`

In `Sources/AudraCore/ReadSelectionCoordinator.swift`:
- the speed sink becomes `.sink { [weak speech] speed in speech?.changeSpeed(speed) }`;
- the speak call becomes `speech.speak(text, voiceID: voiceID, speed: settings.speed)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: all tests pass (the app target also compiles; `AppModel` doesn't call `speak` directly).

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "refactor: pass SpeechSpeed to synthesizers instead of AVSpeech rate

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Natural voice quality and catalog order

**Files:**
- Modify: `Sources/AudraCore/Voices/VoiceInfo.swift`
- Modify: `Sources/AudraCore/Voices/VoiceSelector.swift`
- Test: `Tests/AudraCoreTests/VoiceSelectorTests.swift`

**Interfaces:**
- Produces: `VoiceInfo.Quality.natural` (raw value 4); `VoiceInfo.sortOrder: Int` (default 0; lower is preferred among voices of equal quality); `VoiceInfo.init(id:name:language:quality:sortOrder:)` with `sortOrder: Int = 0`; `menuLabel` for `.natural` is `"<name> (<language>, Natural)"`.

- [ ] **Step 1: Write the failing tests**

Append to `VoiceSelectorTests` (inside the class):

```swift
    private let kokoroAlpha = VoiceInfo(id: "kokoro.jf_alpha", name: "Alpha", language: "ja-JP", quality: .natural, sortOrder: 40)
    private let kokoroHeart = VoiceInfo(id: "kokoro.af_heart", name: "Heart", language: "en-US", quality: .natural, sortOrder: 0)
    private let kokoroBella = VoiceInfo(id: "kokoro.af_bella", name: "Bella", language: "en-US", quality: .natural, sortOrder: 1)

    private func selectWithNatural(
        _ language: String?,
        default defaultVoiceID: String? = nil,
        overrides: [String: String] = [:],
        voices: [VoiceInfo]
    ) -> String? {
        VoiceSelector.selectVoice(
            detectedLanguage: language,
            defaultVoiceID: defaultVoiceID,
            languageOverrides: overrides,
            availableVoices: voices
        )
    }

    func testNaturalVoiceOutranksPremium() {
        XCTAssertEqual(selectWithNatural("ja", voices: [kyoko, kokoroAlpha]), "kokoro.jf_alpha")
    }

    func testEqualQualityPrefersLowerSortOrderOverName() {
        // "Bella" sorts before "Heart" by name, but Heart is first in catalog order.
        XCTAssertEqual(selectWithNatural("en", voices: [samantha, kokoroBella, kokoroHeart]), "kokoro.af_heart")
    }

    func testDefaultSystemVoiceInDetectedLanguageStillBeatsNaturalVoice() {
        XCTAssertEqual(selectWithNatural("ja", default: "ja.kyoko", voices: [kyoko, kokoroAlpha]), "ja.kyoko")
    }

    func testOverrideToUnavailableNaturalVoiceFallsThrough() {
        XCTAssertEqual(selectWithNatural("ja", overrides: ["ja": "kokoro.jf_alpha"], voices: [kyoko]), "ja.kyoko")
    }

    func testNaturalMenuLabel() {
        XCTAssertEqual(kokoroAlpha.menuLabel, "Alpha (ja-JP, Natural)")
    }

    func testSortOrderDefaultsToZero() {
        XCTAssertEqual(samantha.sortOrder, 0)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter VoiceSelectorTests`
Expected: compile errors `type 'VoiceInfo.Quality' has no member 'natural'` and `extra argument 'sortOrder'`.

- [ ] **Step 3: Implement**

In `Sources/AudraCore/Voices/VoiceInfo.swift`:
- add `case natural = 4` after `case premium = 3`, with the comment `/// Kokoro neural voice.`;
- add a stored property after `quality`:

```swift
    /// Preference among voices of the same quality; lower wins. System voices are all 0;
    /// Kokoro voices use their catalog position.
    public let sortOrder: Int
```

- change the initializer to:

```swift
    public init(id: String, name: String, language: String, quality: Quality, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.sortOrder = sortOrder
    }
```

- add to `menuLabel`'s switch: `case .natural: return "\(name) (\(language), Natural)"`.

In `Sources/AudraCore/Voices/VoiceSelector.swift`, update rule 3 in the doc comment to `/// 3. the best-quality installed voice for the detected language (ties: sortOrder, then name A–Z),` and replace the `.max` comparator with:

```swift
            .max { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder > rhs.sortOrder }
                return lhs.name > rhs.name
            }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Voices Tests/AudraCoreTests/VoiceSelectorTests.swift
git commit -m "feat: add natural voice quality and catalog sort order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Kokoro voice catalog

**Files:**
- Create: `Sources/AudraCore/Kokoro/KokoroVoiceCatalog.swift`
- Test: `Tests/AudraCoreTests/KokoroVoiceCatalogTests.swift`

**Interfaces:**
- Consumes: `VoiceInfo(id:name:language:quality:sortOrder:)` (Task 2).
- Produces:
  - `enum KokoroLanguage: String, CaseIterable, Sendable` with cases `americanEnglish = "en-US"`, `britishEnglish = "en-GB"`, `brazilianPortuguese = "pt-BR"`, `spanish = "es-ES"`, `french = "fr-FR"`, `italian = "it-IT"`, `hindi = "hi-IN"`, `japanese = "ja-JP"`, `mandarinChinese = "zh-CN"`.
  - `struct KokoroVoice: Equatable, Sendable` with `id: String` (e.g. `"pf_dora"`), `language: KokoroLanguage`, `voiceID: String` (`"kokoro.pf_dora"`), `name: String` (`"Dora"`).
  - `enum KokoroVoiceCatalog` with `static let voiceIDPrefix = "kokoro."`, `static let all: [KokoroVoice]`, `static func voice(forVoiceID: String) -> KokoroVoice?`, `static func isKokoroVoiceID(_: String?) -> Bool`, `static func defaultVoice(for: KokoroLanguage) -> KokoroVoice?`, `static func voiceInfos() -> [VoiceInfo]`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/KokoroVoiceCatalogTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class KokoroVoiceCatalogTests: XCTestCase {
    func testCatalogHas51UniqueVoicesCoveringEveryLanguage() {
        let ids = KokoroVoiceCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, 51)
        XCTAssertEqual(Set(ids).count, 51)
        for language in KokoroLanguage.allCases {
            XCTAssertNotNil(KokoroVoiceCatalog.defaultVoice(for: language), "\(language)")
        }
        XCTAssertFalse(ids.contains { $0.hasSuffix("_santa") })
    }

    func testDefaultVoices() {
        let defaults = KokoroLanguage.allCases.map { KokoroVoiceCatalog.defaultVoice(for: $0)?.id }
        XCTAssertEqual(defaults, ["af_heart", "bf_emma", "pf_dora", "ef_dora", "ff_siwis", "if_sara", "hf_alpha", "jf_alpha", "zf_xiaobei"])
    }

    func testVoiceIDsAndNames() {
        let dora = KokoroVoiceCatalog.voice(forVoiceID: "kokoro.pf_dora")
        XCTAssertEqual(dora?.language, .brazilianPortuguese)
        XCTAssertEqual(dora?.name, "Dora")
        XCTAssertEqual(dora?.voiceID, "kokoro.pf_dora")
        XCTAssertEqual(KokoroVoiceCatalog.voice(forVoiceID: "kokoro.jf_gongitsune")?.name, "Gongitsune")
        XCTAssertNil(KokoroVoiceCatalog.voice(forVoiceID: "pt.luciana"))
        XCTAssertNil(KokoroVoiceCatalog.voice(forVoiceID: "kokoro.nobody"))
    }

    func testIsKokoroVoiceID() {
        XCTAssertTrue(KokoroVoiceCatalog.isKokoroVoiceID("kokoro.af_heart"))
        XCTAssertFalse(KokoroVoiceCatalog.isKokoroVoiceID("com.apple.voice.compact.en-US.Samantha"))
        XCTAssertFalse(KokoroVoiceCatalog.isKokoroVoiceID(nil))
    }

    func testVoiceInfosUseNaturalQualityAndCatalogOrder() {
        let infos = KokoroVoiceCatalog.voiceInfos()
        XCTAssertEqual(infos.count, 51)
        XCTAssertEqual(infos.first, VoiceInfo(id: "kokoro.af_heart", name: "Heart", language: "en-US", quality: .natural, sortOrder: 0))
        XCTAssertEqual(infos.map(\.sortOrder), Array(0..<51))
        XCTAssertTrue(infos.allSatisfy { $0.quality == .natural })
        XCTAssertEqual(infos.first { $0.id == "kokoro.pf_dora" }?.language, "pt-BR")
        XCTAssertEqual(infos.first { $0.id == "kokoro.zf_xiaobei" }?.languageCode, "zh")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter KokoroVoiceCatalogTests`
Expected: compile error `cannot find 'KokoroVoiceCatalog' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Kokoro/KokoroVoiceCatalog.swift`:

```swift
import Foundation

/// Languages the Kokoro model speaks. Raw values are the BCP-47 tags shown in voice pickers.
public enum KokoroLanguage: String, CaseIterable, Sendable {
    case americanEnglish = "en-US"
    case britishEnglish = "en-GB"
    case brazilianPortuguese = "pt-BR"
    case spanish = "es-ES"
    case french = "fr-FR"
    case italian = "it-IT"
    case hindi = "hi-IN"
    case japanese = "ja-JP"
    case mandarinChinese = "zh-CN"
}

/// One Kokoro v1.0 voice, e.g. `pf_dora` (Brazilian Portuguese, female).
public struct KokoroVoice: Equatable, Sendable {
    /// Kokoro's voice name, also the key in `voices.npz`.
    public let id: String
    public let language: KokoroLanguage

    /// Identifier used in settings and `SpeechSynthesizing.speak`.
    public var voiceID: String { KokoroVoiceCatalog.voiceIDPrefix + id }

    /// "pf_dora" → "Dora".
    public var name: String {
        let base = id.split(separator: "_").last.map(String.init) ?? id
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

public enum KokoroVoiceCatalog {
    public static let voiceIDPrefix = "kokoro."

    /// Voices per language, most preferred first. Novelty voices (*_santa) are left out.
    /// Must match the voice list in scripts/prepare-kokoro-assets.py.
    private static let voicesByLanguage: [(KokoroLanguage, [String])] = [
        (.americanEnglish, ["af_heart", "af_bella", "af_nicole", "af_aoede", "af_kore", "af_sarah", "af_nova",
                            "af_sky", "af_alloy", "af_jessica", "af_river", "am_michael", "am_fenrir", "am_puck",
                            "am_echo", "am_eric", "am_liam", "am_onyx", "am_adam"]),
        (.britishEnglish, ["bf_emma", "bf_isabella", "bf_alice", "bf_lily", "bm_george", "bm_fable", "bm_lewis", "bm_daniel"]),
        (.brazilianPortuguese, ["pf_dora", "pm_alex"]),
        (.spanish, ["ef_dora", "em_alex"]),
        (.french, ["ff_siwis"]),
        (.italian, ["if_sara", "im_nicola"]),
        (.hindi, ["hf_alpha", "hf_beta", "hm_omega", "hm_psi"]),
        (.japanese, ["jf_alpha", "jf_gongitsune", "jf_nezumi", "jf_tebukuro", "jm_kumo"]),
        (.mandarinChinese, ["zf_xiaobei", "zf_xiaoni", "zf_xiaoxiao", "zf_xiaoyi", "zm_yunjian", "zm_yunxi",
                            "zm_yunxia", "zm_yunyang"]),
    ]

    /// Every voice in preference order.
    public static let all: [KokoroVoice] = voicesByLanguage.flatMap { language, ids in
        ids.map { KokoroVoice(id: $0, language: language) }
    }

    public static func voice(forVoiceID voiceID: String) -> KokoroVoice? {
        guard voiceID.hasPrefix(voiceIDPrefix) else { return nil }
        let id = String(voiceID.dropFirst(voiceIDPrefix.count))
        return all.first { $0.id == id }
    }

    public static func isKokoroVoiceID(_ voiceID: String?) -> Bool {
        voiceID?.hasPrefix(voiceIDPrefix) ?? false
    }

    public static func defaultVoice(for language: KokoroLanguage) -> KokoroVoice? {
        all.first { $0.language == language }
    }

    /// The catalog as voice-list entries, `sortOrder` = catalog position.
    public static func voiceInfos() -> [VoiceInfo] {
        all.enumerated().map { index, voice in
            VoiceInfo(id: voice.voiceID, name: voice.name, language: voice.language.rawValue, quality: .natural, sortOrder: index)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter KokoroVoiceCatalogTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Kokoro Tests/AudraCoreTests/KokoroVoiceCatalogTests.swift
git commit -m "feat: add Kokoro voice catalog

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Sentence splitting

**Files:**
- Create: `Sources/AudraCore/Speech/SentenceSplitter.swift`
- Test: `Tests/AudraCoreTests/SentenceSplitterTests.swift`

**Interfaces:**
- Produces: `enum SentenceSplitter` with `struct Sentence: Equatable, Sendable { text: String; offset: Int }` (`offset` = UTF-16 offset of the first non-whitespace character in the original text), `static func sentences(in: String) -> [Sentence]`, `static func subdivide(_: String) -> [String]`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/SentenceSplitterTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class SentenceSplitterTests: XCTestCase {
    private typealias Sentence = SentenceSplitter.Sentence

    func testSplitsSentencesWithUTF16Offsets() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "Hello there. How are you?"), [
            Sentence(text: "Hello there.", offset: 0),
            Sentence(text: "How are you?", offset: 13),
        ])
    }

    func testOffsetsSkipLeadingWhitespace() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "  First one.\n\nSecond"), [
            Sentence(text: "First one.", offset: 2),
            Sentence(text: "Second", offset: 14),
        ])
    }

    func testJapaneseSentences() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "今日は晴れです。明日は雨です。"), [
            Sentence(text: "今日は晴れです。", offset: 0),
            Sentence(text: "明日は雨です。", offset: 8),
        ])
    }

    func testOffsetsCountUTF16NotCharacters() {
        // "👋" is one Character but two UTF-16 code units.
        XCTAssertEqual(SentenceSplitter.sentences(in: "Hi 👋. Bye.").map(\.offset), [0, 7])
    }

    func testWhitespaceOnlyTextHasNoSentences() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "  \n "), [])
    }

    func testSubdivideAtClausePunctuation() {
        XCTAssertEqual(SentenceSplitter.subdivide("one, two; three"), ["one,", "two;", "three"])
        XCTAssertEqual(SentenceSplitter.subdivide("今日は、晴れ"), ["今日は、", "晴れ"])
    }

    func testSubdivideWithoutPunctuationSplitsWordsInHalf() {
        XCTAssertEqual(SentenceSplitter.subdivide("alpha beta gamma delta"), ["alpha beta", "gamma delta"])
    }

    func testSubdivideWithoutSpacesSplitsCharactersInHalf() {
        XCTAssertEqual(SentenceSplitter.subdivide("あいうえ"), ["あい", "うえ"])
        XCTAssertEqual(SentenceSplitter.subdivide("a"), ["a"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SentenceSplitterTests`
Expected: compile error `cannot find 'SentenceSplitter' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Speech/SentenceSplitter.swift`:

```swift
import Foundation
import NaturalLanguage

/// Splits text into the units Kokoro synthesizes one at a time.
public enum SentenceSplitter {
    public struct Sentence: Equatable, Sendable {
        public let text: String
        /// UTF-16 offset of the sentence's first character in the original text.
        public let offset: Int

        public init(text: String, offset: Int) {
            self.text = text
            self.offset = offset
        }
    }

    /// Sentences of `text`, trimmed, with their UTF-16 offsets. Blank sentences are dropped.
    public static func sentences(in text: String) -> [Sentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [Sentence] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = text[range]
            guard let start = raw.firstIndex(where: { !$0.isWhitespace }) else { return true }
            let trimmed = raw[start...].trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(Sentence(text: trimmed, offset: NSRange(start..<range.upperBound, in: text).location))
            return true
        }
        return result
    }

    private static let clausePunctuation: Set<Character> = [",", ";", ":", "、", "，", "；", "："]

    /// Splits an over-long sentence into shorter pieces: after clause punctuation if it has any,
    /// otherwise into two halves at a space, otherwise into two halves by character.
    public static func subdivide(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if clausePunctuation.contains(character) {
                parts.append(current)
                current = ""
            }
        }
        parts.append(current)
        parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.count > 1 { return parts }

        let words = text.split(separator: " ")
        if words.count > 1 {
            let middle = words.count / 2
            return [words[..<middle].joined(separator: " "), words[middle...].joined(separator: " ")]
        }
        guard text.count > 1 else { return [text] }
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        return [String(text[..<middle]), String(text[middle...])]
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SentenceSplitterTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Speech/SentenceSplitter.swift Tests/AudraCoreTests/SentenceSplitterTests.swift
git commit -m "feat: add sentence splitter for Kokoro synthesis

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Phonemizer protocol, joiner and fallback

**Files:**
- Create: `Sources/AudraCore/Phonemes/Phonemizer.swift`
- Test: `Tests/AudraCoreTests/PhonemizerTests.swift`

**Interfaces:**
- Produces:
  - `protocol Phonemizer: Sendable { func phonemize(_ text: String) throws -> String }`
  - `struct PhonemeJoiner` (internal) with `mutating appendWord(_:)`, `mutating appendPunctuation(_:)`, `var text: String`
  - `struct FallbackPhonemizer: Phonemizer` with `init(primary: any Phonemizer, fallback: (any Phonemizer)?)`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/PhonemizerTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class PhonemizerTests: XCTestCase {
    private struct Failing: Phonemizer {
        struct Failure: Error {}
        func phonemize(_ text: String) throws -> String { throw Failure() }
    }

    private struct Echo: Phonemizer {
        let prefix: String
        func phonemize(_ text: String) throws -> String { prefix + text }
    }

    func testJoinerSeparatesWordsAndAttachesClosingPunctuation() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("kono")
        joiner.appendWord("apɯɾʲi")
        joiner.appendPunctuation(",")
        joiner.appendWord("βa")
        joiner.appendPunctuation(".")
        XCTAssertEqual(joiner.text, "kono apɯɾʲi, βa.")
    }

    func testJoinerOpeningPunctuationStartsANewWord() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("a")
        joiner.appendPunctuation("“")
        joiner.appendWord("b")
        joiner.appendPunctuation("”")
        XCTAssertEqual(joiner.text, "a “b”")
    }

    func testJoinerIgnoresEmptyWords() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("")
        joiner.appendWord("a")
        XCTAssertEqual(joiner.text, "a")
    }

    func testFallbackUsesPrimaryWhenItSucceeds() throws {
        let phonemizer = FallbackPhonemizer(primary: Echo(prefix: "p:"), fallback: Echo(prefix: "f:"))
        XCTAssertEqual(try phonemizer.phonemize("x"), "p:x")
    }

    func testFallbackUsedWhenPrimaryThrows() throws {
        let phonemizer = FallbackPhonemizer(primary: Failing(), fallback: Echo(prefix: "f:"))
        XCTAssertEqual(try phonemizer.phonemize("x"), "f:x")
    }

    func testFallbackRethrowsWithoutFallback() {
        XCTAssertThrowsError(try FallbackPhonemizer(primary: Failing(), fallback: nil).phonemize("x"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter PhonemizerTests`
Expected: compile error `cannot find type 'Phonemizer' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Phonemes/Phonemizer.swift`:

```swift
import Foundation

/// Converts text in one language to the phoneme symbols Kokoro was trained on (misaki's set).
public protocol Phonemizer: Sendable {
    func phonemize(_ text: String) throws -> String
}

/// Uses `primary`, and `fallback` for text `primary` throws on.
public struct FallbackPhonemizer: Phonemizer {
    private let primary: any Phonemizer
    private let fallback: (any Phonemizer)?

    public init(primary: any Phonemizer, fallback: (any Phonemizer)?) {
        self.primary = primary
        self.fallback = fallback
    }

    public func phonemize(_ text: String) throws -> String {
        do {
            return try primary.phonemize(text)
        } catch {
            guard let fallback else { throw error }
            return try fallback.phonemize(text)
        }
    }
}

/// Joins per-word phonemes and punctuation the way misaki does for Kokoro: words separated by
/// single spaces, closing punctuation attached to the previous word, opening punctuation to the next.
struct PhonemeJoiner {
    private var result = ""
    private static let opening: Set<Character> = ["“", "(", "[", "«", "¿", "¡"]

    mutating func appendWord(_ phonemes: String) {
        guard !phonemes.isEmpty else { return }
        if let last = result.last, last != " ", !Self.opening.contains(last) { result += " " }
        result += phonemes
    }

    mutating func appendPunctuation(_ mark: String) {
        guard let first = mark.first else { return }
        if Self.opening.contains(first) {
            if let last = result.last, last != " " { result += " " }
        } else {
            while result.last == " " { result.removeLast() }
        }
        result += mark
    }

    var text: String {
        result.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter PhonemizerTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Phonemes Tests/AudraCoreTests/PhonemizerTests.swift
git commit -m "feat: add phonemizer protocol, joiner and fallback

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```


---

### Task 6: Japanese number reader

**Files:**
- Create: `Sources/AudraCore/Phonemes/JapaneseNumberReader.swift`
- Test: `Tests/AudraCoreTests/JapaneseNumberReaderTests.swift`

**Interfaces:**
- Produces: `enum JapaneseNumberReader` with `static let counters: Set<String>` (年 月 日 時 分 円 人 つ 歳 回 個), `static func reading(of number: String) -> String`, `static func reading(of number: String, counter: String) -> String`. Readings are pronunciation hiragana with long vowels written `ー` (e.g. じゅー), so the kana→phoneme step yields `ː`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/JapaneseNumberReaderTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class JapaneseNumberReaderTests: XCTestCase {
    func testPlainNumbers() {
        let cases: [(String, String)] = [
            ("0", "ぜろ"), ("300", "さんびゃく"), ("8000", "はっせん"), ("2026", "にせんにじゅーろく"),
            ("10000", "いちまん"), ("123456789", "いちおくにせんさんびゃくよんじゅーごまんろくせんななひゃくはちじゅーきゅー"),
            ("007", "ぜろぜろなな"), ("3.5", "さんてんご"),
        ]
        for (number, reading) in cases {
            XCTAssertEqual(JapaneseNumberReader.reading(of: number), reading, number)
        }
    }

    func testCounters() {
        let cases: [(String, String, String)] = [
            ("1", "日", "ついたち"), ("14", "日", "じゅーよっか"), ("15", "日", "じゅーごにち"), ("20", "日", "はつか"),
            ("4", "月", "しがつ"), ("2024", "年", "にせんにじゅーよねん"), ("9", "時", "くじ"),
            ("1", "分", "いっぷん"), ("3", "分", "さんぷん"), ("5", "分", "ごふん"), ("10", "分", "じゅっぷん"),
            ("1", "人", "ひとり"), ("4", "人", "よにん"), ("100", "円", "ひゃくえん"), ("3", "つ", "みっつ"),
            ("20", "歳", "はたち"), ("8", "回", "はっかい"), ("6", "個", "ろっこ"),
        ]
        for (number, counter, reading) in cases {
            XCTAssertEqual(JapaneseNumberReader.reading(of: number, counter: counter), reading, number + counter)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter JapaneseNumberReaderTests`
Expected: compile error `cannot find 'JapaneseNumberReader' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Phonemes/JapaneseNumberReader.swift`:

```swift
import Foundation

/// Japanese readings of numbers written in digits, as pronunciation kana (long vowels written ー).
public enum JapaneseNumberReader {
    public static let counters: Set<String> = ["年", "月", "日", "時", "分", "円", "人", "つ", "歳", "回", "個"]

    private static let digitReadings = ["ぜろ", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅー"]

    /// Reading of a decimal number such as "2026" or "3.5".
    public static func reading(of number: String) -> String {
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        let integer = reading(ofInteger: String(parts[0]))
        guard parts.count == 2, !parts[1].isEmpty else { return integer }
        return integer + "てん" + parts[1].compactMap { $0.wholeNumberValue }.map { digitReadings[$0] }.joined()
    }

    /// Reading of a whole number followed by `counter` (one of `counters`), e.g. ("1", "日") → "ついたち".
    public static func reading(of number: String, counter: String) -> String {
        guard let value = Int(number), !number.hasPrefix("0") || number == "0" else {
            return reading(of: number) + counterReading(counter)
        }
        let base = reading(ofInteger: number)
        switch counter {
        case "月":
            return replacingSuffix(of: base, [("よん", "し"), ("なな", "しち"), ("きゅー", "く")]) + "がつ"
        case "日":
            let special = [1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか", 6: "むいか",
                           7: "なのか", 8: "よーか", 9: "ここのか", 10: "とーか", 14: "じゅーよっか",
                           20: "はつか", 24: "にじゅーよっか"]
            return special[value] ?? base + "にち"
        case "年":
            return replacingSuffix(of: base, [("よん", "よ"), ("きゅー", "く")]) + "ねん"
        case "時":
            return replacingSuffix(of: base, [("よん", "よ"), ("なな", "しち"), ("きゅー", "く")]) + "じ"
        case "分":
            switch value % 10 {
            case 1, 6, 8: return sokuon(base) + "ぷん"
            case 3, 4: return base + "ぷん"
            case 0 where value > 0: return sokuon(base) + "ぷん"
            default: return base + "ふん"
            }
        case "円":
            return replacingSuffix(of: base, [("よん", "よ")]) + "えん"
        case "人":
            if value == 1 { return "ひとり" }
            if value == 2 { return "ふたり" }
            return replacingSuffix(of: base, [("よん", "よ")]) + "にん"
        case "つ":
            let special = [1: "ひとつ", 2: "ふたつ", 3: "みっつ", 4: "よっつ", 5: "いつつ", 6: "むっつ",
                           7: "ななつ", 8: "やっつ", 9: "ここのつ", 10: "とお"]
            return special[value] ?? base
        case "歳":
            if value == 20 { return "はたち" }
            return [1, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "さい" : base + "さい"
        case "回":
            return [1, 6, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "かい" : base + "かい"
        case "個":
            return [1, 6, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "こ" : base + "こ"
        default:
            return base + counter
        }
    }

    private static func counterReading(_ counter: String) -> String {
        ["年": "ねん", "月": "がつ", "日": "にち", "時": "じ", "分": "ふん", "円": "えん", "人": "にん",
         "つ": "つ", "歳": "さい", "回": "かい", "個": "こ"][counter] ?? counter
    }

    private static func reading(ofInteger digits: String) -> String {
        let values = digits.compactMap { $0.wholeNumberValue }
        guard !values.isEmpty else { return "" }
        // Leading zeros (e.g. "007") and very long numbers are read digit by digit.
        if values.count > 16 || (values.count > 1 && values[0] == 0) {
            return values.map { digitReadings[$0] }.joined()
        }
        if values.allSatisfy({ $0 == 0 }) { return digitReadings[0] }
        let units = ["", "まん", "おく", "ちょー"]
        var groups: [Int] = []
        var remaining = values
        while !remaining.isEmpty {
            let group = remaining.suffix(4)
            remaining.removeLast(group.count)
            groups.append(group.reduce(0) { $0 * 10 + $1 })
        }
        var result = ""
        for (index, group) in groups.enumerated().reversed() where group > 0 {
            if index == 3 && group == 1 {
                result += "いっちょー"
            } else {
                result += readingBelow10000(group) + units[index]
            }
        }
        return result
    }

    private static func readingBelow10000(_ value: Int) -> String {
        let thousands = value / 1000, hundreds = value / 100 % 10, tens = value / 10 % 10, ones = value % 10
        var result = ""
        switch thousands {
        case 0: break
        case 1: result += "せん"
        case 3: result += "さんぜん"
        case 8: result += "はっせん"
        default: result += digitReadings[thousands] + "せん"
        }
        switch hundreds {
        case 0: break
        case 1: result += "ひゃく"
        case 3: result += "さんびゃく"
        case 6: result += "ろっぴゃく"
        case 8: result += "はっぴゃく"
        default: result += digitReadings[hundreds] + "ひゃく"
        }
        switch tens {
        case 0: break
        case 1: result += "じゅー"
        default: result += digitReadings[tens] + "じゅー"
        }
        if ones > 0 { result += digitReadings[ones] }
        return result
    }

    private static func sokuon(_ reading: String) -> String {
        replacingSuffix(of: reading, [("いち", "いっ"), ("ろく", "ろっ"), ("はち", "はっ"), ("じゅー", "じゅっ"), ("ひゃく", "ひゃっ")])
    }

    private static func replacingSuffix(of reading: String, _ replacements: [(String, String)]) -> String {
        for (suffix, replacement) in replacements where reading.hasSuffix(suffix) {
            return String(reading.dropLast(suffix.count)) + replacement
        }
        return reading
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JapaneseNumberReaderTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Phonemes/JapaneseNumberReader.swift Tests/AudraCoreTests/JapaneseNumberReaderTests.swift
git commit -m "feat: add Japanese number reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Japanese phonemizer

How it works: digits (+ counter) are read by `JapaneseNumberReader`. The rest goes through `CFStringTokenizer` (ja), which yields a Latin transcription of each word's reading, converted to hiragana. Kana words keep their own spelling, and the particles は/へ/を become わ/え/お. In the kanji part of a word, long vowels become ー (とうきょう → とーきょー). Finally, misaki's cutlet table turns kana into phonemes. On the sample sentence this reproduces misaki's official output exactly.

**Files:**
- Create: `Sources/AudraCore/Phonemes/JapaneseKanaTable.swift`
- Create: `Sources/AudraCore/Phonemes/JapanesePhonemizer.swift`
- Test: `Tests/AudraCoreTests/JapanesePhonemizerTests.swift`

**Interfaces:**
- Consumes: `Phonemizer`, `PhonemeJoiner` (Task 5), `JapaneseNumberReader` (Task 6).
- Produces: `struct JapanesePhonemizer: Phonemizer` (`init()`). Internal statics used by tests: `phonemes(forKana:)`, `lengthenVowels(_:keepingLast:)`, `reading(surface:latin:)`, `hiragana(fromKatakana:)`, `numberSegments(_:)`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/JapanesePhonemizerTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class JapanesePhonemizerTests: XCTestCase {
    private let phonemizer = JapanesePhonemizer()

    func testMatchesMisakiReferenceSentence() throws {
        // Reference output of misaki's JAG2P (cutlet) for the same sentence.
        XCTAssertEqual(
            try phonemizer.phonemize("スクリーンリーダーは、書かれた文章を音声に変換します。"),
            "sɨkɯɾʲiːɴ ɾʲiːdaː βa, kaka ɾe ta bɯɴɕoː o oɴseː ɲi heŋkaɴ ɕi masɨ."
        )
    }

    func testParticlesAndLongVowels() throws {
        XCTAssertEqual(try phonemizer.phonemize("東京へ行きます。本を読んでください。"),
                       "toːkʲoː e ikʲi masɨ. hoɴ o joɴ de kɯdasai.")
        XCTAssertEqual(try phonemizer.phonemize("学校の先生"), "ɡaʔkoː no seɴseː")
    }

    func testSokuonAndExclamation() throws {
        XCTAssertEqual(try phonemizer.phonemize("ちょっと待って！"), "ʨoʔto maʔte!")
    }

    func testNumbersWithCounters() throws {
        XCTAssertEqual(try phonemizer.phonemize("今日は2026年10月1日です。"),
                       "kʲoː βa ɲiseɲɲiʥɨːɾokɯneɴ ʥɨːɡaʦɨ ʦɨitaʨi desɨ.")
    }

    func testKanaToPhonemes() {
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "さんま"), "samma")
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "こんにちわ"), "koɲɲiʨiβa")
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "りーだー"), "ɾʲiːdaː")
    }

    func testLengthenVowelsOnlyInKanjiPart() {
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("とうきょう", keepingLast: 0), "とーきょー")
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("せんせい", keepingLast: 0), "せんせー")
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("おもう", keepingLast: 1), "おもう")
    }

    func testReadings() {
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "は", latin: "ha"), "わ")
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "東京", latin: "toukyou"), "とーきょー")
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "思う", latin: "omou"), "おもう")
        XCTAssertNil(JapanesePhonemizer.reading(surface: "東京", latin: nil))
        XCTAssertEqual(JapanesePhonemizer.hiragana(fromKatakana: "リーダー"), "りーだー")
    }

    func testNumberSegments() {
        XCTAssertEqual(JapanesePhonemizer.numberSegments("今日は2026年と3.5キロ"), [
            .text("今日は"), .number("2026", counter: "年"), .text("と"), .number("3.5", counter: nil), .text("キロ"),
        ])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter JapanesePhonemizerTests`
Expected: compile error `cannot find 'JapanesePhonemizer' in scope`.

- [ ] **Step 3: Add the kana table**

Create `Sources/AudraCore/Phonemes/JapaneseKanaTable.swift`. This is misaki's `cutlet.py` `HEPBURN` table: 164 kana and digraphs, 25 symbols and 2 combining marks, 191 entries.

```swift
import Foundation

/// Kana → Kokoro phonemes, ported from misaki's cutlet table (MIT/Apache-2.0).
enum JapaneseKanaTable {
    static let table: [String: String] = [
        "ぁ": "a",
        "あ": "a",
        "ぃ": "i",
        "い": "i",
        "ぅ": "ɯ",
        "う": "ɯ",
        "ぇ": "e",
        "え": "e",
        "ぉ": "o",
        "お": "o",
        "か": "ka",
        "が": "ɡa",
        "き": "kʲi",
        "ぎ": "ɡʲi",
        "く": "kɯ",
        "ぐ": "ɡɯ",
        "け": "ke",
        "げ": "ɡe",
        "こ": "ko",
        "ご": "ɡo",
        "さ": "sa",
        "ざ": "ʣa",
        "し": "ɕi",
        "じ": "ʥi",
        "す": "sɨ",
        "ず": "zɨ",
        "せ": "se",
        "ぜ": "ʣe",
        "そ": "so",
        "ぞ": "ʣo",
        "た": "ta",
        "だ": "da",
        "ち": "ʨi",
        "ぢ": "ʥi",
        "っ": "#",
        "つ": "ʦɨ",
        "づ": "zɨ",
        "て": "te",
        "で": "de",
        "と": "to",
        "ど": "do",
        "な": "na",
        "に": "ɲi",
        "ぬ": "nɯ",
        "ね": "ne",
        "の": "no",
        "は": "ha",
        "ば": "ba",
        "ぱ": "pa",
        "ひ": "çi",
        "び": "bʲi",
        "ぴ": "pʲi",
        "ふ": "ɸɯ",
        "ぶ": "bɯ",
        "ぷ": "pɯ",
        "へ": "he",
        "べ": "be",
        "ぺ": "pe",
        "ほ": "ho",
        "ぼ": "bo",
        "ぽ": "po",
        "ま": "ma",
        "み": "mʲi",
        "む": "mɯ",
        "め": "me",
        "も": "mo",
        "ゃ": "ja",
        "や": "ja",
        "ゅ": "jɯ",
        "ゆ": "jɯ",
        "ょ": "jo",
        "よ": "jo",
        "ら": "ɾa",
        "り": "ɾʲi",
        "る": "ɾɯ",
        "れ": "ɾe",
        "ろ": "ɾo",
        "ゎ": "βa",
        "わ": "βa",
        "ゐ": "i",
        "ゑ": "e",
        "を": "o",
        "ん": "#",
        "ゔ": "vɯ",
        "ゕ": "ka",
        "ゖ": "ke",
        "ヷ": "va",
        "ヸ": "vʲi",
        "ヹ": "ve",
        "ヺ": "vo",
        "いぇ": "je",
        "うぃ": "βi",
        "うぇ": "βe",
        "うぉ": "βo",
        "きぇ": "kʲe",
        "きゃ": "kʲa",
        "きゅ": "kʲɨ",
        "きょ": "kʲo",
        "ぎゃ": "ɡʲa",
        "ぎゅ": "ɡʲɨ",
        "ぎょ": "ɡʲo",
        "くぁ": "kᵝa",
        "くぃ": "kᵝi",
        "くぇ": "kᵝe",
        "くぉ": "kᵝo",
        "ぐぁ": "ɡᵝa",
        "ぐぃ": "ɡᵝi",
        "ぐぇ": "ɡᵝe",
        "ぐぉ": "ɡᵝo",
        "しぇ": "ɕe",
        "しゃ": "ɕa",
        "しゅ": "ɕɨ",
        "しょ": "ɕo",
        "じぇ": "ʥe",
        "じゃ": "ʥa",
        "じゅ": "ʥɨ",
        "じょ": "ʥo",
        "ちぇ": "ʨe",
        "ちゃ": "ʨa",
        "ちゅ": "ʨɨ",
        "ちょ": "ʨo",
        "ぢゃ": "ʥa",
        "ぢゅ": "ʥɨ",
        "ぢょ": "ʥo",
        "つぁ": "ʦa",
        "つぃ": "ʦʲi",
        "つぇ": "ʦe",
        "つぉ": "ʦo",
        "てぃ": "tʲi",
        "てゅ": "tʲɨ",
        "でぃ": "dʲi",
        "でゅ": "dʲɨ",
        "とぅ": "tɯ",
        "どぅ": "dɯ",
        "にぇ": "ɲe",
        "にゃ": "ɲa",
        "にゅ": "ɲɨ",
        "にょ": "ɲo",
        "ひぇ": "çe",
        "ひゃ": "ça",
        "ひゅ": "çɨ",
        "ひょ": "ço",
        "びゃ": "bʲa",
        "びゅ": "bʲɨ",
        "びょ": "bʲo",
        "ぴゃ": "pʲa",
        "ぴゅ": "pʲɨ",
        "ぴょ": "pʲo",
        "ふぁ": "ɸa",
        "ふぃ": "ɸʲi",
        "ふぇ": "ɸe",
        "ふぉ": "ɸo",
        "ふゅ": "ɸʲɨ",
        "ふょ": "ɸʲo",
        "みゃ": "mʲa",
        "みゅ": "mʲɨ",
        "みょ": "mʲo",
        "りゃ": "ɾʲa",
        "りゅ": "ɾʲɨ",
        "りょ": "ɾʲo",
        "ゔぁ": "va",
        "ゔぃ": "vʲi",
        "ゔぇ": "ve",
        "ゔぉ": "vo",
        "ゔゅ": "bʲɨ",
        "ゔょ": "bʲo",
        "。": ".",
        "、": ",",
        "？": "?",
        "！": "!",
        "「": "“",
        "」": "”",
        "『": "“",
        "』": "”",
        "：": ":",
        "；": ";",
        "（": "(",
        "）": ")",
        "《": "(",
        "》": ")",
        "【": "[",
        "】": "]",
        "・": " ",
        "，": ",",
        "～": "—",
        "〜": "—",
        "—": "—",
        "«": "“",
        "»": "”",
        "゚": "",
        "゙": "",
    ]
}
```

- [ ] **Step 4: Implement the phonemizer**

Create `Sources/AudraCore/Phonemes/JapanesePhonemizer.swift`:

```swift
import Foundation

/// Japanese text → Kokoro phonemes. Kanji readings come from the system tokenizer
/// (`CFStringTokenizer`), then misaki's cutlet rules turn kana into phonemes. No pitch accent.
public struct JapanesePhonemizer: Phonemizer {
    public init() {}

    public func phonemize(_ text: String) throws -> String {
        var joiner = PhonemeJoiner()
        let normalized = text.precomposedStringWithCompatibilityMapping
        for segment in Self.numberSegments(normalized) {
            switch segment {
            case let .number(digits, counter):
                let kana = counter.map { JapaneseNumberReader.reading(of: digits, counter: $0) }
                    ?? JapaneseNumberReader.reading(of: digits)
                joiner.appendWord(Self.phonemes(forKana: kana))
            case let .text(part):
                Self.appendTokens(of: part, to: &joiner)
            }
        }
        return Self.mergeSokuonSpaces(joiner.text)
    }

    // MARK: - Numbers

    enum Segment: Equatable {
        case number(String, counter: String?)
        case text(String)
    }

    private static let numberPattern = try! NSRegularExpression(
        pattern: "(\\d+(?:\\.\\d+)?)(" + JapaneseNumberReader.counters.sorted().joined(separator: "|") + ")?"
    )

    static func numberSegments(_ text: String) -> [Segment] {
        let ns = text as NSString
        var segments: [Segment] = []
        var cursor = 0
        for match in numberPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                segments.append(.text(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            let digits = ns.substring(with: match.range(at: 1))
            let counterRange = match.range(at: 2)
            let counter = counterRange.location == NSNotFound ? nil : ns.substring(with: counterRange)
            segments.append(.number(digits, counter: digits.contains(".") ? nil : counter))
            if counter != nil && digits.contains(".") {
                segments.append(.text(ns.substring(with: counterRange)))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { segments.append(.text(ns.substring(from: cursor))) }
        return segments
    }

    // MARK: - Tokens

    private static let punctuationMap: [Character: String] = [
        "。": ".", "、": ",", "，": ",", "？": "?", "?": "?", "！": "!", "!": "!", "：": ":", ":": ":",
        "；": ";", ";": ";", ".": ".", ",": ",", "「": "“", "」": "”", "『": "“", "』": "”",
        "（": "(", "）": ")", "(": "(", ")": ")", "《": "(", "》": ")", "【": "[", "】": "]",
        "«": "“", "»": "”", "～": "—", "〜": "—", "—": "—", "…": "…",
    ]

    /// Particles whose pronunciation differs from their spelling.
    private static let particles: [String: String] = ["は": "わ", "へ": "え", "を": "お"]

    private static func appendTokens(of text: String, to joiner: inout PhonemeJoiner) {
        let cf = text as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cf, CFRangeMake(0, CFStringGetLength(cf)), kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "ja") as CFLocale
        )
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let surface = (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
            if surface.allSatisfy({ punctuationMap[$0] != nil }) {
                surface.forEach { joiner.appendPunctuation(punctuationMap[$0]!) }
                continue
            }
            if surface.allSatisfy(\.isWhitespace) { continue }
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            guard let kana = reading(surface: surface, latin: latin) else { continue }
            joiner.appendWord(phonemes(forKana: kana))
        }
    }

    /// Hiragana pronunciation of one token.
    static func reading(surface: String, latin: String?) -> String? {
        if let particle = particles[surface] { return particle }
        if surface.unicodeScalars.allSatisfy(isKana) {
            return hiragana(fromKatakana: surface)
        }
        guard let latin, !latin.isEmpty else { return nil }
        let converted = NSMutableString(string: latin)
        CFStringTransform(converted, nil, kCFStringTransformLatinHiragana, false)
        let kana = converted as String
        guard kana.unicodeScalars.allSatisfy(isKana) else { return nil }
        // Okurigana (trailing kana of the surface) keep their spelling; the kanji part gets long vowels.
        let trailingKana = surface.reversed().prefix { $0.unicodeScalars.allSatisfy(isKana) }.count
        return lengthenVowels(kana, keepingLast: trailingKana)
    }

    private static func isKana(_ scalar: Unicode.Scalar) -> Bool {
        (0x3041...0x309F).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
    }

    /// Katakana → hiragana by code point (ァ…ヶ → ぁ…ゖ). ー and ヷ…ヺ are kept: the system
    /// transform would turn ー into a vowel.
    static func hiragana(fromKatakana text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            (0x30A1...0x30F6).contains(scalar.value) ? Unicode.Scalar(scalar.value - 0x60)! : scalar
        }))
    }

    /// Dictionary pronunciations write long vowels as ー: とうきょう → とーきょー, せんせい → せんせー.
    static func lengthenVowels(_ kana: String, keepingLast keep: Int) -> String {
        var characters = Array(kana)
        let limit = characters.count - keep
        guard limit > 1 else { return kana }
        for index in 1..<limit {
            guard let previous = JapaneseKanaTable.table[String(characters[index - 1])]?.last else { continue }
            switch characters[index] {
            case "う" where "oɯɨ".contains(previous), "お" where previous == "o", "い" where previous == "e":
                characters[index] = "ー"
            default:
                break
            }
        }
        return String(characters)
    }

    // MARK: - Kana → phonemes (cutlet's _get_single_mapping)

    private static let smallKana: Set<Character> = ["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ"]

    static func phonemes(forKana kana: String) -> String {
        let table = JapaneseKanaTable.table
        let characters = Array(hiragana(fromKatakana: kana))
        var out = ""
        for (index, character) in characters.enumerated() {
            let current = String(character)
            let previous = index > 0 ? String(characters[index - 1]) : nil
            let next = index + 1 < characters.count ? String(characters[index + 1]) : nil
            if let previous, let digraph = table[previous + current] {
                out += digraph
            } else if let next, table[current + next] != nil {
                continue
            } else if let next, smallKana.contains(Character(next)) {
                if current == "っ" { continue }
                out += String((table[current] ?? "").dropLast()) + (table[next] ?? "")
            } else if smallKana.contains(character) {
                continue
            } else if current == "ー" {
                out += "ː"
            } else if current == "っ" {
                out += "ʔ"
            } else if current == "ん" {
                out += moraicNasal(before: next.flatMap { table[$0] })
            } else {
                out += table[current] ?? ""
            }
        }
        return out
    }

    private static func moraicNasal(before next: String?) -> String {
        guard let next, let first = next.first else { return "ɴ" }
        if "mpb".contains(first) { return "m" }
        if "kɡ".contains(first) { return "ŋ" }
        if ["ɲ", "ʨ", "ʥ"].contains(where: next.hasPrefix) { return "ɲ" }
        if "ntdɾz".contains(first) { return "n" }
        return "ɴ"
    }

    /// cutlet joins a sokuon to its neighbours: "ʔ" never has spaces around it.
    static func mergeSokuonSpaces(_ phonemes: String) -> String {
        phonemes
            .replacingOccurrences(of: "(?<![!\",.:;?»—…”]) (?=ʔ)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?<=ʔ) (?![\"«“])", with: "", options: .regularExpression)
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter JapanesePhonemizerTests`
Expected: 8 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/AudraCore/Phonemes Tests/AudraCoreTests/JapanesePhonemizerTests.swift
git commit -m "feat: add Japanese phonemizer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Pinyin transcription and Chinese numbers

**Files:**
- Create: `Sources/AudraCore/Phonemes/PinyinTranscriber.swift`
- Create: `Sources/AudraCore/Phonemes/ChineseNumberReader.swift`
- Test: `Tests/AudraCoreTests/PinyinTranscriberTests.swift`

**Interfaces:**
- Produces:
  - `enum PinyinTranscriber` with `struct Syllable(letters:tone:)` (`letters` toneless, `ü` written `v`; `tone` 1–5, where 5 is neutral), `static func phonemes(for: Syllable) -> String?`, `static func isValid(_ letters: String) -> Bool`, `static func syllables(in pinyin: String, count: Int) -> [Syllable]?`.
  - `enum ChineseNumberReader` with `static func reading(of: String) -> String` and `static func digitByDigit(_: String) -> String`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/PinyinTranscriberTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class PinyinTranscriberTests: XCTestCase {
    private typealias Syllable = PinyinTranscriber.Syllable

    func testSplitsToneMarkedPinyinIntoSyllables() {
        XCTAssertEqual(PinyinTranscriber.syllables(in: "jīntiān", count: 2), [Syllable("jin", tone: 1), Syllable("tian", tone: 1)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "wǒmen", count: 2), [Syllable("wo", tone: 3), Syllable("men", tone: 5)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "nv̌ér", count: 2), [Syllable("nv", tone: 3), Syllable("er", tone: 2)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "lv̀sè", count: 2), [Syllable("lv", tone: 4), Syllable("se", tone: 4)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "xī'ān", count: 2), [Syllable("xi", tone: 1), Syllable("an", tone: 1)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "xiān", count: 1), [Syllable("xian", tone: 1)])
    }

    func testRejectsTextThatIsNotPinyin() {
        XCTAssertNil(PinyinTranscriber.syllables(in: "bcd", count: 1))
        XCTAssertNil(PinyinTranscriber.syllables(in: "jīntiān", count: 8)) // more syllables than letters
    }

    func testSyllablePhonemesMatchMisaki() {
        let cases: [(Syllable, String)] = [
            (Syllable("zhong", tone: 1), "ꭧʊ→ŋ"), (Syllable("guo", tone: 2), "kwo↗"), (Syllable("shi", tone: 4), "ʂɨ↘"),
            (Syllable("zi", tone: 4), "ʦɨ↘"), (Syllable("yu", tone: 3), "y↓"), (Syllable("jue", tone: 2), "ʨɥe↗"),
            (Syllable("nv", tone: 3), "ny↓"), (Syllable("er", tone: 2), "ɚ↗"), (Syllable("men", tone: 5), "mən"),
            (Syllable("qu", tone: 4), "ʨʰy↘"), (Syllable("tian", tone: 1), "tʰjɛ→n"), (Syllable("huan", tone: 1), "xwa→n"),
            (Syllable("hao", tone: 3), "xau↓"), (Syllable("you", tone: 3), "jou↓"), (Syllable("wo", tone: 3), "wo↓"),
        ]
        for (syllable, phonemes) in cases {
            XCTAssertEqual(PinyinTranscriber.phonemes(for: syllable), phonemes, syllable.letters)
        }
        XCTAssertNil(PinyinTranscriber.phonemes(for: Syllable("xx", tone: 1)))
    }

    func testChineseNumbers() {
        let cases: [(String, String)] = [
            ("0", "零"), ("3", "三"), ("10", "十"), ("15", "十五"), ("100", "一百"), ("105", "一百零五"),
            ("1010", "一千零一十"), ("2026", "二千零二十六"), ("10001", "一万零一"), ("120000", "十二万"),
            ("3.5", "三点五"), ("100000000", "一亿"),
        ]
        for (number, reading) in cases {
            XCTAssertEqual(ChineseNumberReader.reading(of: number), reading, number)
        }
        XCTAssertEqual(ChineseNumberReader.digitByDigit("2026"), "二零二六")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter PinyinTranscriberTests`
Expected: compile error `cannot find 'PinyinTranscriber' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Phonemes/PinyinTranscriber.swift`:

```swift
import Foundation

/// Pinyin syllables → Kokoro phonemes, ported from misaki's `transcription.py` and `ZHG2P.retone`
/// (pinyin-to-ipa, MIT). Tones become arrows: 1 →, 2 ↗, 3 ↓, 4 ↘, neutral nothing.
public enum PinyinTranscriber {
    /// A toneless pinyin syllable ("zhong", "nü") and its tone, 1–5 (5 = neutral).
    public struct Syllable: Equatable, Sendable {
        public let letters: String
        public let tone: Int
        public init(_ letters: String, tone: Int) {
            self.letters = letters
            self.tone = tone
        }
    }

    private static let initials: [String: String] = [
        "b": "p", "c": "ʦʰ", "ch": "ꭧʰ", "d": "t", "f": "f", "g": "k", "h": "x", "j": "ʨ", "k": "kʰ",
        "l": "l", "m": "m", "n": "n", "p": "pʰ", "q": "ʨʰ", "r": "ɻ", "s": "s", "sh": "ʂ", "t": "tʰ",
        "x": "ɕ", "z": "ʦ", "zh": "ꭧ",
    ]

    /// Finals in pypinyin's strict spelling; "0" marks where the tone goes.
    private static let finals: [String: String] = [
        "a": "a0", "ai": "ai0", "an": "a0n", "ang": "a0ŋ", "ao": "au0", "e": "ɤ0", "ei": "ei0",
        "en": "ə0n", "eng": "ə0ŋ", "i": "i0", "ia": "ja0", "ian": "jɛ0n", "iang": "ja0ŋ", "iao": "jau0",
        "ie": "je0", "in": "i0n", "iou": "jou0", "ing": "i0ŋ", "iong": "jʊ0ŋ", "ong": "ʊ0ŋ", "ou": "ou0",
        "u": "u0", "uei": "wei0", "ua": "wa0", "uai": "wai0", "uan": "wa0n", "uen": "wə0n",
        "uang": "wa0ŋ", "ueng": "wə0ŋ", "uo": "wo0", "o": "wo0", "ü": "y0", "üe": "ɥe0", "üan": "ɥɛ0n",
        "ün": "y0n",
    ]

    /// Whole syllables with no initial/final split.
    private static let special: [String: String] = [
        "er": "ɚ0", "io": "jɔ0", "ê": "ɛ0", "o": "ɔ0", "hm": "hm0", "hng": "hŋ0", "m": "m0", "n": "n0", "ng": "ŋ0",
    ]

    private static let toneArrows = [1: "→", 2: "↗", 3: "↓", 4: "↘", 5: ""]

    /// Phonemes for one syllable, or nil if it is not valid pinyin.
    public static func phonemes(for syllable: Syllable) -> String? {
        guard let arrow = toneArrows[syllable.tone] else { return nil }
        let letters = syllable.letters.replacingOccurrences(of: "v", with: "ü")
        let ipa: String
        if let whole = special[letters] {
            ipa = whole
        } else if let (initial, final) = split(letters) {
            let finalIPA: String
            if final == "i" && ["zh", "ch", "sh", "r"].contains(initial) {
                finalIPA = "ɨ0"
            } else if final == "i" && ["z", "c", "s"].contains(initial) {
                finalIPA = "ɨ0"
            } else {
                guard let mapped = finals[final] else { return nil }
                finalIPA = mapped
            }
            ipa = (initial.flatMap { initials[$0] } ?? "") + finalIPA
        } else {
            return nil
        }
        return ipa.replacingOccurrences(of: "0", with: arrow)
    }

    public static func isValid(_ letters: String) -> Bool {
        phonemes(for: Syllable(letters, tone: 5)) != nil
    }

    /// Splits a toneless syllable into (initial, strict final), applying pinyin spelling rules
    /// (y/w, iu → iou, ui → uei, un → uen, u → ü after j/q/x).
    private static func split(_ letters: String) -> (String?, String)? {
        let yw: [String: String] = [
            "yi": "i", "ya": "ia", "ye": "ie", "yao": "iao", "you": "iou", "yan": "ian", "yin": "in",
            "yang": "iang", "ying": "ing", "yong": "iong", "yu": "ü", "yue": "üe", "yuan": "üan", "yun": "ün",
            "wu": "u", "wa": "ua", "wo": "uo", "wai": "uai", "wei": "uei", "wan": "uan", "wen": "uen",
            "wang": "uang", "weng": "ueng",
        ]
        if let final = yw[letters] { return (nil, final) }
        guard let initial = ["zh", "ch", "sh"].first(where: letters.hasPrefix)
            ?? letters.first.map(String.init).flatMap({ initials[$0] != nil ? $0 : nil })
        else {
            return finals[letters] != nil ? (nil, letters) : nil
        }
        var final = String(letters.dropFirst(initial.count))
        if ["j", "q", "x"].contains(initial) {
            final = ["u": "ü", "ue": "üe", "uan": "üan", "un": "ün"][final] ?? final
        }
        final = ["iu": "iou", "ui": "uei", "un": "uen", "ue": "üe"][final] ?? final
        return finals[final] != nil ? (initial, final) : nil
    }

    /// Splits tone-marked pinyin for `count` syllables, e.g. ("jīntiān", 2) → [jin1, tian1].
    /// Returns nil when the text can't be split into exactly `count` valid syllables.
    public static func syllables(in pinyin: String, count: Int) -> [Syllable]? {
        var letters: [Character] = []
        var tones: [Int] = []
        var boundaries: Set<Int> = []
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x0304: if !tones.isEmpty { tones[tones.count - 1] = 1 }
            case 0x0301: if !tones.isEmpty { tones[tones.count - 1] = 2 }
            case 0x030C: if !tones.isEmpty { tones[tones.count - 1] = 3 }
            case 0x0300: if !tones.isEmpty { tones[tones.count - 1] = 4 }
            case 0x0308: if letters.last == "u" { letters[letters.count - 1] = "v" }
            case 0x61...0x7A:
                letters.append(Character(scalar))
                tones.append(0)
            default:
                boundaries.insert(letters.count)
            }
        }
        func search(from start: Int, remaining: Int) -> [Range<Int>]? {
            if remaining == 0 { return start == letters.count ? [] : nil }
            let maxLength = min(6, letters.count - start)
            guard maxLength > 0 else { return nil }
            for length in stride(from: maxLength, through: 1, by: -1) {
                let end = start + length
                if (start + 1..<end).contains(where: boundaries.contains) { continue }
                guard isValid(String(letters[start..<end])) else { continue }
                if let rest = search(from: end, remaining: remaining - 1) { return [start..<end] + rest }
            }
            return nil
        }
        guard count > 0, let ranges = search(from: 0, remaining: count) else { return nil }
        return ranges.map { range in
            Syllable(String(letters[range]), tone: tones[range].first(where: { $0 > 0 }) ?? 5)
        }
    }
}
```

Create `Sources/AudraCore/Phonemes/ChineseNumberReader.swift`:

```swift
import Foundation

/// Arabic numerals → Chinese numerals for reading aloud: "2026" → "二千零二十六", "3.5" → "三点五".
public enum ChineseNumberReader {
    private static let digits: [Character] = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    public static func reading(of number: String) -> String {
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        let integer = reading(ofInteger: String(parts[0]))
        guard parts.count == 2, !parts[1].isEmpty else { return integer }
        return integer + "点" + String(parts[1].compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    /// Digit by digit, as years are read: "2026" → "二零二六".
    public static func digitByDigit(_ number: String) -> String {
        String(number.compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    private static func reading(ofInteger text: String) -> String {
        let values = text.compactMap(\.wholeNumberValue)
        guard !values.isEmpty else { return "" }
        if values.count > 16 || (values.count > 1 && values[0] == 0) { return digitByDigit(text) }
        if values.allSatisfy({ $0 == 0 }) { return "零" }
        var groups: [Int] = []
        var remaining = values
        while !remaining.isEmpty {
            let group = remaining.suffix(4)
            remaining.removeLast(group.count)
            groups.append(group.reduce(0) { $0 * 10 + $1 })
        }
        let units = ["", "万", "亿", "万亿"]
        var result = ""
        var pendingZero = false
        for (index, group) in groups.enumerated().reversed() {
            if group == 0 { pendingZero = !result.isEmpty; continue }
            if pendingZero || (!result.isEmpty && group < 1000) { result += "零" }
            pendingZero = false
            result += readingBelow10000(group) + units[index]
        }
        // 一十X at the very start is read 十X.
        if result.hasPrefix("一十") { result.removeFirst() }
        return result
    }

    private static func readingBelow10000(_ value: Int) -> String {
        let places = [(1000, "千"), (100, "百"), (10, "十"), (1, "")]
        var result = ""
        var zero = false
        for (place, unit) in places {
            let digit = value / place % 10
            if digit == 0 {
                zero = !result.isEmpty
                continue
            }
            if zero { result += "零" }
            zero = false
            result += String(digits[digit]) + unit
        }
        return result
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter PinyinTranscriberTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Phonemes Tests/AudraCoreTests/PinyinTranscriberTests.swift
git commit -m "feat: add pinyin transcription and Chinese number reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Chinese phonemizer (beta)

`CFStringTokenizer` (zh-Hans) segments words and gives context-aware tone-marked pinyin per word: 银行 → yínháng. The character-by-character transform would give the wrong yín xíng. The pinyin is split into one syllable per Han character and transcribed with `PinyinTranscriber`. On the reference sentences this reproduces misaki's output exactly.

**Files:**
- Create: `Sources/AudraCore/Phonemes/ChinesePhonemizer.swift`
- Test: `Tests/AudraCoreTests/ChinesePhonemizerTests.swift`

**Interfaces:**
- Consumes: `Phonemizer`, `PhonemeJoiner` (Task 5), `PinyinTranscriber`, `ChineseNumberReader` (Task 8).
- Produces: `struct ChinesePhonemizer: Phonemizer` (`init()`); internal `static func replacingNumbers(in: String) -> String`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/ChinesePhonemizerTests.swift`:

```swift
import XCTest
@testable import AudraCore

final class ChinesePhonemizerTests: XCTestCase {
    private let phonemizer = ChinesePhonemizer()

    func testMatchesMisakiReferenceSentences() throws {
        // Reference outputs of misaki's ZHG2P (Kokoro v1.0) for the same sentences.
        XCTAssertEqual(try phonemizer.phonemize("我们今天去银行。"), "wo↓mən ʨi→ntʰjɛ→n ʨʰy↘ i↗nxa↗ŋ.")
        XCTAssertEqual(try phonemizer.phonemize("女儿喜欢绿色的衣服。"), "ny↓ɚ↗ ɕi↓xwa→n ly↘sɤ↘ tɤ i→fu↗.")
        XCTAssertEqual(try phonemizer.phonemize("你好，世界！"), "ni↓xau↓, ʂɨ↘ʨje↘!")
    }

    func testPunctuationBetweenClauses() throws {
        XCTAssertEqual(try phonemizer.phonemize("我是学生，他是老师。"), "wo↓ ʂɨ↘ ɕɥe↗ʂə→ŋ, tʰa→ ʂɨ↘ lau↓ʂɨ→.")
    }

    func testNumbersBecomeChineseNumerals() {
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "我有3本书"), "我有三本书")
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "2026年"), "二零二六年")
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "15年"), "十五年")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter ChinesePhonemizerTests`
Expected: compile error `cannot find 'ChinesePhonemizer' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Phonemes/ChinesePhonemizer.swift`:

```swift
import Foundation

/// Mandarin text → Kokoro phonemes (beta). Word segmentation and context-aware pinyin come from
/// the system tokenizer (`CFStringTokenizer`); pinyin → phonemes follows misaki.
public struct ChinesePhonemizer: Phonemizer {
    public init() {}

    private static let punctuationMap: [Character: String] = [
        "、": ",", "，": ",", ",": ",", "。": ".", "．": ".", ".": ".", "！": "!", "!": "!", "：": ":", ":": ":",
        "；": ";", ";": ";", "？": "?", "?": "?", "«": "“", "»": "”", "《": "“", "》": "”", "「": "“",
        "」": "”", "【": "“", "】": "”", "（": "(", "）": ")", "(": "(", ")": ")", "…": "…", "—": "—",
    ]

    private static let numberPattern = try! NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?(年)?")

    public func phonemize(_ text: String) throws -> String {
        let withNumerals = Self.replacingNumbers(in: text.precomposedStringWithCompatibilityMapping)
        var joiner = PhonemeJoiner()
        let cf = withNumerals as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cf, CFRangeMake(0, CFStringGetLength(cf)), kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "zh-Hans") as CFLocale
        )
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let surface = (withNumerals as NSString).substring(with: NSRange(location: range.location, length: range.length))
            if surface.allSatisfy({ Self.punctuationMap[$0] != nil }) {
                surface.forEach { joiner.appendPunctuation(Self.punctuationMap[$0]!) }
                continue
            }
            let hanCount = surface.unicodeScalars.filter(Self.isHan).count
            guard hanCount > 0 else {
                // Latin words pass through as misaki does; anything else is dropped.
                let latin = surface.filter { $0.isASCII && $0.isLetter }
                if !latin.isEmpty { joiner.appendWord(latin.lowercased()) }
                continue
            }
            let pinyin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            joiner.appendWord(Self.phonemes(surface: surface, pinyin: pinyin, hanCount: hanCount))
        }
        return joiner.text
    }

    static func phonemes(surface: String, pinyin: String?, hanCount: Int) -> String {
        if let pinyin, let syllables = PinyinTranscriber.syllables(in: pinyin, count: hanCount) {
            return syllables.compactMap(PinyinTranscriber.phonemes(for:)).joined()
        }
        // Fall back to character-by-character pinyin when the word's transcription can't be split.
        return surface.unicodeScalars.filter(isHan).compactMap { scalar -> String? in
            let converted = NSMutableString(string: String(Character(scalar)))
            CFStringTransform(converted, nil, kCFStringTransformMandarinLatin, false)
            return PinyinTranscriber.syllables(in: converted as String, count: 1)?
                .first.flatMap(PinyinTranscriber.phonemes(for:))
        }.joined()
    }

    static func replacingNumbers(in text: String) -> String {
        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in numberPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = ns.substring(with: match.range)
            if token.hasSuffix("年") {
                let digits = String(token.dropLast())
                result += (digits.count == 4 ? ChineseNumberReader.digitByDigit(digits) : ChineseNumberReader.reading(of: digits)) + "年"
            } else {
                result += ChineseNumberReader.reading(of: token)
            }
            cursor = match.range.location + match.range.length
        }
        return result + ns.substring(from: cursor)
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter ChinesePhonemizerTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Phonemes/ChinesePhonemizer.swift Tests/AudraCoreTests/ChinesePhonemizerTests.swift
git commit -m "feat: add Chinese phonemizer (beta)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Kokoro synthesizer

**Files:**
- Modify: `Sources/AudraCore/Speech/SpeechSynthesizing.swift` (add `FallibleSpeechSynthesizing`)
- Create: `Sources/AudraCore/Kokoro/KokoroEngine.swift`
- Create: `Sources/AudraCore/Speech/AudioOutput.swift`
- Create: `Sources/AudraCore/Kokoro/KokoroSynthesizer.swift`
- Create: `Tests/AudraCoreTests/Fakes/KokoroFakes.swift`
- Test: `Tests/AudraCoreTests/KokoroSynthesizerTests.swift`

**Interfaces:**
- Consumes: `SpeechSynthesizing`, `SpeechSpeed` (Task 1); `KokoroVoiceCatalog`, `KokoroLanguage` (Task 3); `SentenceSplitter` (Task 4); `Phonemizer` (Task 5).
- Produces:
  - `protocol FallibleSpeechSynthesizing: SpeechSynthesizing { var onEngineFailure: (@MainActor (Int) -> Void)? { get set } }`. The argument is the UTF-16 offset in the text given to `speak` from which another engine should continue.
  - `protocol KokoroEngine: AnyObject, Sendable { func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] }`. `voiceID` is the Kokoro name, e.g. `"af_heart"`. It returns 24 kHz mono samples.
  - `enum KokoroEngineError: Error, Equatable { case unavailable, tooManyTokens }`.
  - `protocol AudioOutput: AnyObject` (`@MainActor`) with `schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void)`, `pause()`, `resume()`, `stop()`. `final class AVAudioEngineOutput: AudioOutput` with `init()`.
  - `final class KokoroSynthesizer: FallibleSpeechSynthesizing` with `init(engine: any KokoroEngine, output: any AudioOutput, phonemizer: @escaping @MainActor (KokoroLanguage) -> (any Phonemizer)?)` and `static let maxPhonemes = 510`.

- [ ] **Step 1: Add the test fakes**

Create `Tests/AudraCoreTests/Fakes/KokoroFakes.swift`:

```swift
import Foundation
@testable import AudraCore

@MainActor
final class FakeKokoroEngine: KokoroEngine {
    struct Call: Equatable {
        let phonemes: String
        let voiceID: String
        let speed: Float
    }

    struct Failure: Error {}

    private(set) var calls: [Call] = []
    /// Thrown by every call.
    var error: (any Error)?
    /// Phonemes that throw `Failure`.
    var failingPhonemes: Set<String> = []
    /// Phonemes that throw `KokoroEngineError.unavailable`.
    var unavailablePhonemes: Set<String> = []
    /// While true, calls wait until `release()`.
    var holdsCalls = false
    private var held: [CheckedContinuation<Void, Never>] = []

    func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] {
        calls.append(Call(phonemes: phonemes, voiceID: voiceID, speed: speed))
        if holdsCalls { await withCheckedContinuation { held.append($0) } }
        if let error { throw error }
        if unavailablePhonemes.contains(phonemes) { throw KokoroEngineError.unavailable }
        if failingPhonemes.contains(phonemes) { throw Failure() }
        return Array(repeating: 0.1, count: phonemes.unicodeScalars.count)
    }

    func release() {
        holdsCalls = false
        held.forEach { $0.resume() }
        held = []
    }
}

/// Mirrors `AVAudioEngineOutput`: the first queued buffer starts at once, each next one when
/// the previous ends, and nothing is reported after `stop()`.
@MainActor
final class FakeAudioOutput: AudioOutput {
    struct Item {
        let samples: [Float]
        let onStart: @MainActor () -> Void
        let onEnd: @MainActor () -> Void
    }

    private(set) var queue: [Item] = []
    private(set) var scheduledCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var stopCount = 0

    func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void) {
        queue.append(Item(samples: samples, onStart: onStart, onEnd: onEnd))
        scheduledCount += 1
        if queue.count == 1 { onStart() }
    }

    /// Simulates the playing buffer reaching its end.
    func finishCurrent() {
        guard !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        finished.onEnd()
        queue.first?.onStart()
    }

    func pause() { pauseCount += 1 }
    func resume() { resumeCount += 1 }

    func stop() {
        stopCount += 1
        queue.removeAll()
    }
}

/// Returns the text itself as "phonemes".
struct FakePhonemizer: Phonemizer {
    struct Failure: Error {}
    var failing: Set<String> = []

    func phonemize(_ text: String) throws -> String {
        if failing.contains(text) { throw Failure() }
        return text
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/AudraCoreTests/KokoroSynthesizerTests.swift`:

```swift
import XCTest
@testable import AudraCore

@MainActor
final class KokoroSynthesizerTests: XCTestCase {
    private var engine: FakeKokoroEngine!
    private var output: FakeAudioOutput!
    private var synthesizer: KokoroSynthesizer!
    private var phonemizer = FakePhonemizer()
    private var hasPhonemizer = true
    private var requestedLanguages: [KokoroLanguage] = []
    private var progress: [Int] = []
    private var failures: [Int] = []
    private var finishCount = 0

    private func makeSynthesizer() {
        engine = FakeKokoroEngine()
        output = FakeAudioOutput()
        requestedLanguages = []
        progress = []
        failures = []
        finishCount = 0
        synthesizer = KokoroSynthesizer(engine: engine, output: output, phonemizer: { [unowned self] language in
            self.requestedLanguages.append(language)
            return self.hasPhonemizer ? self.phonemizer : nil
        })
        synthesizer.onProgress = { [unowned self] in self.progress.append($0) }
        synthesizer.onFinish = { [unowned self] in self.finishCount += 1 }
        synthesizer.onEngineFailure = { [unowned self] in self.failures.append($0) }
    }

    /// Lets the synthesis task run until it waits on the engine or for a free buffer slot.
    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }

    private func speak(_ text: String, voiceID: String = "kokoro.af_heart", speed: SpeechSpeed = .normal) async {
        synthesizer.speak(text, voiceID: voiceID, speed: speed)
        await settle()
    }

    func testSynthesizesTwoSentencesAheadAndPlaysInOrder() async {
        makeSynthesizer()
        await speak("One. Two. Three. Four. Five.")
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Two.", "Three."])
        XCTAssertEqual(output.queue.count, 3)
        XCTAssertEqual(progress, [0])

        output.finishCurrent()
        await settle()
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Two.", "Three.", "Four."])
        XCTAssertEqual(progress, [0, 5])
    }

    func testFinishesAfterTheLastSentencePlays() async {
        makeSynthesizer()
        await speak("One. Two.")
        output.finishCurrent()
        XCTAssertEqual(progress, [0, 5])
        XCTAssertEqual(finishCount, 0)
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testEmptyTextFinishesImmediately() async {
        makeSynthesizer()
        await speak("   ")
        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(engine.calls, [])
    }

    func testUsesTheVoicesLanguageAndSpeed() async {
        makeSynthesizer()
        await speak("Olá.", voiceID: "kokoro.pf_dora", speed: .oneAndHalf)
        XCTAssertEqual(requestedLanguages, [.brazilianPortuguese])
        XCTAssertEqual(engine.calls, [FakeKokoroEngine.Call(phonemes: "Olá.", voiceID: "pf_dora", speed: 1.5)])
    }

    func testStopDropsQueuedAudioAndPendingSentences() async {
        makeSynthesizer()
        await speak("One. Two. Three. Four. Five.")
        synthesizer.stop()
        XCTAssertEqual(output.stopCount, 1)
        XCTAssertTrue(output.queue.isEmpty)
        await settle()
        XCTAssertEqual(engine.calls.count, 3)
        XCTAssertEqual(finishCount, 0)
    }

    func testResultArrivingAfterStopIsDiscarded() async {
        makeSynthesizer()
        engine.holdsCalls = true
        await speak("One.")
        XCTAssertEqual(engine.calls.count, 1)
        synthesizer.stop()
        engine.release()
        await settle()
        XCTAssertEqual(output.scheduledCount, 0)
        XCTAssertEqual(progress, [])
        XCTAssertEqual(finishCount, 0)
    }

    func testSpeakReplacesTheCurrentReading() async {
        makeSynthesizer()
        await speak("Old one. Old two.")
        await speak("New.")
        XCTAssertEqual(output.stopCount, 1)
        XCTAssertEqual(engine.calls.last?.phonemes, "New.")
        XCTAssertEqual(output.queue.count, 1)
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testSkipsASentenceThatFailsToPhonemize() async {
        makeSynthesizer()
        phonemizer.failing = ["Two."]
        await speak("One. Two. Three.")
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Three."])
        output.finishCurrent()
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testSkipsASentenceTheEngineFailsOn() async {
        makeSynthesizer()
        engine.failingPhonemes = ["Two."]
        await speak("One. Two. Three.")
        XCTAssertEqual(output.scheduledCount, 2)
        XCTAssertEqual(failures, [])
    }

    func testUnavailableEngineHandsOverFromTheStart() async {
        makeSynthesizer()
        engine.error = KokoroEngineError.unavailable
        await speak("One. Two.")
        XCTAssertEqual(failures, [0])
        XCTAssertEqual(finishCount, 0)
    }

    func testUnavailableEngineHandsOverFromTheSentencePlaying() async {
        makeSynthesizer()
        engine.unavailablePhonemes = ["Four."]
        await speak("One. Two. Three. Four.")
        output.finishCurrent() // "Two." starts playing, "Four." gets synthesized and fails
        await settle()
        XCTAssertEqual(failures, [5])
        XCTAssertGreaterThanOrEqual(output.stopCount, 1)
        XCTAssertEqual(finishCount, 0)
    }

    func testUnknownVoiceOrMissingPhonemizerFailsImmediately() {
        makeSynthesizer()
        synthesizer.speak("Hi.", voiceID: "pt.luciana", speed: .normal)
        XCTAssertEqual(failures, [0])
        hasPhonemizer = false
        synthesizer.speak("Hi.", voiceID: "kokoro.af_heart", speed: .normal)
        XCTAssertEqual(failures, [0, 0])
        XCTAssertEqual(engine.calls, [])
        hasPhonemizer = true
    }

    func testPauseAndResumeGoToTheOutputWhileReading() async {
        makeSynthesizer()
        synthesizer.pause()
        XCTAssertEqual(output.pauseCount, 0)
        await speak("One.")
        synthesizer.pause()
        synthesizer.resume()
        XCTAssertEqual(output.pauseCount, 1)
        XCTAssertEqual(output.resumeCount, 1)
    }

    func testOverLongSentenceIsSplitUnderTheTokenLimit() async {
        makeSynthesizer()
        let sentence = Array(repeating: "palavra", count: 100).joined(separator: ", ") + "."
        await speak(sentence)
        XCTAssertEqual(engine.calls.count, 2)
        XCTAssertTrue(engine.calls.allSatisfy { $0.phonemes.unicodeScalars.count <= KokoroSynthesizer.maxPhonemes })
        XCTAssertEqual(output.scheduledCount, 1)
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter KokoroSynthesizerTests`
Expected: compile errors such as `cannot find type 'KokoroEngine' in scope`.

- [ ] **Step 4: Add the protocols**

Append to `Sources/AudraCore/Speech/SpeechSynthesizing.swift`:

```swift

/// A synthesizer that can find out mid-reading that it can't go on, e.g. the Kokoro model is missing.
@MainActor
public protocol FallibleSpeechSynthesizing: SpeechSynthesizing {
    /// Called instead of `onFinish` when the engine can't speak the rest of the text. The argument
    /// is the UTF-16 offset in the text passed to `speak` from which another engine should continue.
    var onEngineFailure: (@MainActor (Int) -> Void)? { get set }
}
```

Create `Sources/AudraCore/Kokoro/KokoroEngine.swift`:

```swift
import Foundation

/// The Kokoro neural network. The real implementation (MLX) lives in AudraKokoro.
public protocol KokoroEngine: AnyObject, Sendable {
    /// 24 kHz mono samples of `phonemes` spoken by the Kokoro voice `voiceID` (e.g. "af_heart").
    func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float]
}

public enum KokoroEngineError: Error, Equatable {
    /// The model or voice files can't be loaded; readings should fall back to system voices.
    case unavailable
    /// More than `KokoroSynthesizer.maxPhonemes` phonemes.
    case tooManyTokens
}
```

Create `Sources/AudraCore/Speech/AudioOutput.swift`:

```swift
import AVFoundation

/// Plays synthesized sentences back to back.
@MainActor
public protocol AudioOutput: AnyObject {
    /// Queues 24 kHz mono samples after everything already queued. `onStart` runs when this buffer
    /// starts playing, `onEnd` when it has played completely. Neither runs after `stop()`.
    func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void)
    func pause()
    func resume()
    /// Drops everything queued.
    func stop()
}

/// `AudioOutput` on `AVAudioEngine`.
@MainActor
public final class AVAudioEngineOutput: AudioOutput {
    private struct Entry {
        let onStart: @MainActor () -> Void
        let onEnd: @MainActor () -> Void
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
    private var queue: [Entry] = []
    private var isPaused = false
    /// Bumped by `stop()` so completion handlers of dropped buffers are ignored.
    private var epoch = 0

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    public func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void) {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        if !engine.isRunning { try? engine.start() }

        queue.append(Entry(onStart: onStart, onEnd: onEnd))
        let epoch = self.epoch
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.bufferFinished(epoch: epoch) }
        }
        if queue.count == 1 { onStart() }
        if !isPaused && !player.isPlaying { player.play() }
    }

    public func pause() {
        isPaused = true
        player.pause()
    }

    public func resume() {
        isPaused = false
        player.play()
    }

    public func stop() {
        epoch += 1
        queue.removeAll()
        isPaused = false
        player.stop()
        engine.stop()
    }

    private func bufferFinished(epoch: Int) {
        guard epoch == self.epoch, !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        finished.onEnd()
        // onEnd may have stopped playback.
        guard epoch == self.epoch else { return }
        queue.first?.onStart()
    }
}
```

- [ ] **Step 5: Implement the synthesizer**

Create `Sources/AudraCore/Kokoro/KokoroSynthesizer.swift`:

```swift
import Foundation
import os

/// Speaks with Kokoro voices: splits the text into sentences, phonemizes and synthesizes them in
/// order, and plays each as soon as it's ready, keeping up to two sentences synthesized ahead.
/// Progress is reported per sentence.
@MainActor
public final class KokoroSynthesizer: FallibleSpeechSynthesizing {
    /// Kokoro's input limit, in Unicode scalars (its tokenizer maps each scalar to one token).
    public static let maxPhonemes = 510
    /// Buffers queued at most: the sentence playing plus two ahead.
    static let maxQueuedSentences = 3

    public var onFinish: (@MainActor () -> Void)?
    public var onProgress: (@MainActor (Int) -> Void)?
    public var onEngineFailure: (@MainActor (Int) -> Void)?

    private let engine: any KokoroEngine
    private let output: any AudioOutput
    private let phonemizer: @MainActor (KokoroLanguage) -> (any Phonemizer)?
    private var reading: Reading?
    private let logger = Logger(subsystem: "com.buemura.Audra", category: "Kokoro")

    /// State of one `speak` call. Callbacks check `self.reading === reading` to ignore stale work.
    @MainActor
    private final class Reading {
        var task: Task<Void, Never>?
        var queued = 0
        var synthesisDone = false
        var playingOffset: Int?
        var slotWaiter: CheckedContinuation<Void, Never>?

        func freeSlot() {
            slotWaiter?.resume()
            slotWaiter = nil
        }
    }

    public init(
        engine: any KokoroEngine,
        output: any AudioOutput,
        phonemizer: @escaping @MainActor (KokoroLanguage) -> (any Phonemizer)?
    ) {
        self.engine = engine
        self.output = output
        self.phonemizer = phonemizer
    }

    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        stop()
        guard let voice = voiceID.flatMap(KokoroVoiceCatalog.voice(forVoiceID:)),
              let phonemizer = phonemizer(voice.language)
        else {
            onEngineFailure?(0)
            return
        }
        let reading = Reading()
        self.reading = reading
        let sentences = SentenceSplitter.sentences(in: text)
        reading.task = Task { [weak self] in
            await self?.run(reading, sentences: sentences, voice: voice, phonemizer: phonemizer, speed: Float(speed.rawValue))
        }
    }

    public func stop() {
        guard let reading else { return }
        self.reading = nil
        reading.task?.cancel()
        reading.freeSlot()
        output.stop()
    }

    public func pause() {
        if reading != nil { output.pause() }
    }

    public func resume() {
        if reading != nil { output.resume() }
    }

    private func run(
        _ reading: Reading,
        sentences: [SentenceSplitter.Sentence],
        voice: KokoroVoice,
        phonemizer: any Phonemizer,
        speed: Float
    ) async {
        for sentence in sentences {
            while reading.queued >= Self.maxQueuedSentences {
                await withCheckedContinuation { reading.slotWaiter = $0 }
                guard self.reading === reading else { return }
            }
            guard self.reading === reading else { return }

            let samples: [Float]
            do {
                samples = try await synthesize(sentence.text, voice: voice, phonemizer: phonemizer, speed: speed)
            } catch KokoroEngineError.unavailable {
                guard self.reading === reading else { return }
                stop()
                onEngineFailure?(reading.playingOffset ?? sentence.offset)
                return
            } catch {
                logger.error("Skipped a sentence: \(String(describing: type(of: error)), privacy: .public)")
                continue
            }
            guard self.reading === reading else { return }
            guard !samples.isEmpty else { continue }

            reading.queued += 1
            output.schedule(samples, onStart: { [weak self] in
                guard let self, self.reading === reading else { return }
                reading.playingOffset = sentence.offset
                self.onProgress?(sentence.offset)
            }, onEnd: { [weak self] in
                guard let self, self.reading === reading else { return }
                reading.queued -= 1
                reading.freeSlot()
                self.finishIfDone(reading)
            })
        }
        guard self.reading === reading else { return }
        reading.synthesisDone = true
        finishIfDone(reading)
    }

    private func finishIfDone(_ reading: Reading) {
        guard self.reading === reading, reading.synthesisDone, reading.queued == 0 else { return }
        self.reading = nil
        onFinish?()
    }

    private func synthesize(_ text: String, voice: KokoroVoice, phonemizer: any Phonemizer, speed: Float) async throws -> [Float] {
        var samples: [Float] = []
        for chunk in try phonemeChunks(for: text, phonemizer: phonemizer) {
            samples += try await engine.synthesize(phonemes: chunk, voiceID: voice.id, speed: speed)
        }
        return samples
    }

    /// Phonemes for `text` in pieces of at most `maxPhonemes` scalars. Over-long text is split
    /// at clause punctuation (then words, then characters) and the pieces are merged back greedily.
    func phonemeChunks(for text: String, phonemizer: any Phonemizer) throws -> [String] {
        let phonemes = try phonemizer.phonemize(text)
        guard phonemes.unicodeScalars.count > Self.maxPhonemes else {
            return phonemes.isEmpty ? [] : [phonemes]
        }
        let parts = SentenceSplitter.subdivide(text)
        guard parts.count > 1 else {
            return [String(String.UnicodeScalarView(phonemes.unicodeScalars.prefix(Self.maxPhonemes)))]
        }
        var chunks: [String] = []
        for piece in try parts.flatMap({ try phonemeChunks(for: $0, phonemizer: phonemizer) }) {
            if let last = chunks.last, last.unicodeScalars.count + 1 + piece.unicodeScalars.count <= Self.maxPhonemes {
                chunks[chunks.count - 1] = last + " " + piece
            } else {
                chunks.append(piece)
            }
        }
        return chunks
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter KokoroSynthesizerTests`
Expected: 14 tests pass. Then run `swift test`: everything passes.

- [ ] **Step 7: Commit**

```bash
git add Sources/AudraCore Tests/AudraCoreTests
git commit -m "feat: add Kokoro synthesizer with sentence look-ahead

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Routing synthesizer

**Files:**
- Create: `Sources/AudraCore/Speech/RoutingSynthesizer.swift`
- Modify: `Tests/AudraCoreTests/Fakes/FakeSynthesizer.swift` (add `FakeFallibleSynthesizer`)
- Test: `Tests/AudraCoreTests/RoutingSynthesizerTests.swift`

**Interfaces:**
- Consumes: `SpeechSynthesizing`, `FallibleSpeechSynthesizing` (Tasks 1, 10); `KokoroVoiceCatalog.isKokoroVoiceID` (Task 3).
- Produces: `final class RoutingSynthesizer: SpeechSynthesizing` with `init(system: any SpeechSynthesizing, kokoro: any FallibleSpeechSynthesizing, fallbackVoiceID: @escaping @MainActor (String) -> String?)`. `fallbackVoiceID` gets the remaining text and returns the system voice to continue with.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/AudraCoreTests/Fakes/FakeSynthesizer.swift`:

```swift

@MainActor
final class FakeFallibleSynthesizer: FakeSynthesizer, FallibleSpeechSynthesizing {
    var onEngineFailure: (@MainActor (Int) -> Void)?

    /// Simulates the engine giving up; speech should continue from `offset`.
    func failEngine(at offset: Int) { onEngineFailure?(offset) }
}
```

Create `Tests/AudraCoreTests/RoutingSynthesizerTests.swift`:

```swift
import XCTest
@testable import AudraCore

@MainActor
final class RoutingSynthesizerTests: XCTestCase {
    private var system: FakeSynthesizer!
    private var kokoro: FakeFallibleSynthesizer!
    private var routing: RoutingSynthesizer!
    private var fallbackTexts: [String] = []
    private var progress: [Int] = []
    private var finishCount = 0

    private func makeRouting() {
        system = FakeSynthesizer()
        kokoro = FakeFallibleSynthesizer()
        fallbackTexts = []
        progress = []
        finishCount = 0
        routing = RoutingSynthesizer(system: system, kokoro: kokoro, fallbackVoiceID: { [unowned self] text in
            self.fallbackTexts.append(text)
            return "fallback.voice"
        })
        routing.onProgress = { [unowned self] in self.progress.append($0) }
        routing.onFinish = { [unowned self] in self.finishCount += 1 }
    }

    func testKokoroVoicesGoToKokoroAndOthersToTheSystem() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        XCTAssertEqual(kokoro.calls, [.speak(text: "Hi", voiceID: "kokoro.af_heart", speed: .normal)])
        XCTAssertEqual(system.calls, [])

        routing.speak("Hi", voiceID: "en.samantha", speed: .double)
        XCTAssertEqual(kokoro.calls.last, .stop)
        XCTAssertEqual(system.calls, [.speak(text: "Hi", voiceID: "en.samantha", speed: .double)])

        routing.speak("Hi", voiceID: nil, speed: .normal)
        XCTAssertEqual(system.calls.suffix(2), [.stop, .speak(text: "Hi", voiceID: nil, speed: .normal)])
    }

    func testControlsGoToTheActiveEngine() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        routing.pause()
        routing.resume()
        routing.stop()
        routing.pause()
        XCTAssertEqual(kokoro.calls, [.speak(text: "Hi", voiceID: "kokoro.af_heart", speed: .normal), .pause, .resume, .stop])
        XCTAssertEqual(system.calls, [])
    }

    func testOnlyTheActiveEnginesCallbacksAreForwarded() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        routing.speak("Hi", voiceID: "en.samantha", speed: .normal)
        kokoro.progress(to: 3)
        kokoro.finish()
        XCTAssertEqual(progress, [])
        XCTAssertEqual(finishCount, 0)

        system.progress(to: 2)
        system.finish()
        XCTAssertEqual(progress, [2])
        XCTAssertEqual(finishCount, 1)
    }

    func testEngineFailureContinuesWithASystemVoiceFromTheOffset() {
        makeRouting()
        routing.speak("Hello brave world", voiceID: "kokoro.af_heart", speed: .double)
        kokoro.failEngine(at: 6)
        XCTAssertEqual(fallbackTexts, ["brave world"])
        XCTAssertEqual(system.calls, [.speak(text: "brave world", voiceID: "fallback.voice", speed: .double)])

        system.progress(to: 6) // "world"
        XCTAssertEqual(progress, [12])
        system.finish()
        XCTAssertEqual(finishCount, 1)
    }

    func testFailureFromAnInactiveEngineIsIgnored() {
        makeRouting()
        routing.speak("Hi", voiceID: "en.samantha", speed: .normal)
        kokoro.failEngine(at: 0)
        XCTAssertEqual(system.calls.count, 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RoutingSynthesizerTests`
Expected: compile error `cannot find 'RoutingSynthesizer' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Speech/RoutingSynthesizer.swift`:

```swift
import Foundation

/// Sends Kokoro voices to the Kokoro synthesizer and everything else to the system synthesizer.
/// If Kokoro gives up mid-reading, the rest of the text continues with a system voice.
@MainActor
public final class RoutingSynthesizer: SpeechSynthesizing {
    public var onFinish: (@MainActor () -> Void)?
    public var onProgress: (@MainActor (Int) -> Void)?

    private let system: any SpeechSynthesizing
    private let kokoro: any FallibleSpeechSynthesizing
    private let fallbackVoiceID: @MainActor (String) -> String?
    private var active: (any SpeechSynthesizing)?
    private var text = ""
    private var speed: SpeechSpeed = .normal
    /// Where the active engine's text starts within `text` (non-zero after a fallback).
    private var progressBase = 0

    public init(
        system: any SpeechSynthesizing,
        kokoro: any FallibleSpeechSynthesizing,
        fallbackVoiceID: @escaping @MainActor (String) -> String?
    ) {
        self.system = system
        self.kokoro = kokoro
        self.fallbackVoiceID = fallbackVoiceID
        system.onFinish = { [weak self, weak system] in self?.engineFinished(system) }
        system.onProgress = { [weak self, weak system] offset in self?.engineProgressed(system, to: offset) }
        kokoro.onFinish = { [weak self, weak kokoro] in self?.engineFinished(kokoro) }
        kokoro.onProgress = { [weak self, weak kokoro] offset in self?.engineProgressed(kokoro, to: offset) }
        kokoro.onEngineFailure = { [weak self, weak kokoro] offset in self?.engineFailed(kokoro, at: offset) }
    }

    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        active?.stop()
        self.text = text
        self.speed = speed
        progressBase = 0
        let engine: any SpeechSynthesizing = KokoroVoiceCatalog.isKokoroVoiceID(voiceID) ? kokoro : system
        active = engine
        engine.speak(text, voiceID: voiceID, speed: speed)
    }

    public func stop() {
        active?.stop()
        active = nil
    }

    public func pause() { active?.pause() }
    public func resume() { active?.resume() }

    private func isActive(_ engine: (any SpeechSynthesizing)?) -> Bool {
        guard let engine, let active else { return false }
        return engine === active
    }

    private func engineFinished(_ engine: (any SpeechSynthesizing)?) {
        guard isActive(engine) else { return }
        active = nil
        onFinish?()
    }

    private func engineProgressed(_ engine: (any SpeechSynthesizing)?, to offset: Int) {
        guard isActive(engine) else { return }
        onProgress?(progressBase + offset)
    }

    private func engineFailed(_ engine: (any SpeechSynthesizing)?, at offset: Int) {
        guard isActive(engine) else { return }
        let length = (text as NSString).length
        let start = min(progressBase + offset, length)
        let remaining = (text as NSString).substring(from: start)
        progressBase = start
        active = system
        system.speak(remaining, voiceID: fallbackVoiceID(remaining), speed: speed)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: all pass, including 5 new `RoutingSynthesizerTests`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Speech/RoutingSynthesizer.swift Tests/AudraCoreTests
git commit -m "feat: route Kokoro voices to the Kokoro synthesizer with system fallback

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Model store and downloader

**Files:**
- Create: `Sources/AudraCore/Kokoro/KokoroModelStore.swift`
- Create: `Sources/AudraCore/Kokoro/KokoroModelAssets.swift`
- Create: `Sources/AudraCore/Kokoro/URLSessionModelDownloader.swift`
- Create: `Tests/AudraCoreTests/Fakes/FakeModelDownloader.swift`
- Test: `Tests/AudraCoreTests/KokoroModelStoreTests.swift`

**Interfaces:**
- Produces:
  - `protocol ModelDownloading: Sendable { func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL }`. It returns a temporary file that the caller moves.
  - `final class KokoroModelStore: ObservableObject` (`@MainActor`) with:
    - `enum State: Equatable { case notDownloaded, downloading(progress: Double), ready, failed(String) }` and `State.statusText(totalBytes:) -> String`;
    - `struct Asset: Equatable, Sendable` with `init(fileName:url:sha256:byteCount:)`;
    - `init(directory: URL, assets: [Asset], downloader: any ModelDownloading)`;
    - `@Published private(set) var state`, `func url(for fileName: String) -> URL`, `var totalBytes: Int64`, `func start()`, `func download()`, `func remove()`.
  - `enum KokoroModelAssets` with `modelFileName`, `voicesFileName`, `all: [KokoroModelStore.Asset]`.
  - `final class URLSessionModelDownloader: ModelDownloading` with `init()`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/Fakes/FakeModelDownloader.swift`:

```swift
import Foundation
@testable import AudraCore

final class FakeModelDownloader: ModelDownloading, @unchecked Sendable {
    var files: [URL: Data] = [:]
    var error: (any Error)?
    private(set) var requested: [URL] = []

    func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        requested.append(url)
        if let error { throw error }
        guard let data = files[url] else { throw URLError(.fileDoesNotExist) }
        progress(0.5)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: file)
        return file
    }
}
```

Create `Tests/AudraCoreTests/KokoroModelStoreTests.swift`:

```swift
import CryptoKit
import XCTest
@testable import AudraCore

@MainActor
final class KokoroModelStoreTests: XCTestCase {
    private var directory: URL!
    private var downloader: FakeModelDownloader!
    private let modelData = Data("model weights".utf8)
    private let voicesData = Data("voice styles".utf8)
    private let modelURL = URL(string: "https://example.com/model.safetensors")!
    private let voicesURL = URL(string: "https://example.com/voices.npz")!

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeStore(modelChecksum: String? = nil) -> KokoroModelStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KokoroModelStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        self.directory = directory
        downloader = FakeModelDownloader()
        downloader.files = [modelURL: modelData, voicesURL: voicesData]
        return KokoroModelStore(directory: directory, assets: [
            .init(fileName: "model.safetensors", url: modelURL, sha256: modelChecksum ?? sha256(modelData), byteCount: Int64(modelData.count)),
            .init(fileName: "voices.npz", url: voicesURL, sha256: sha256(voicesData), byteCount: Int64(voicesData.count)),
        ], downloader: downloader)
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out", file: file, line: line)
    }

    func testStartDownloadsVerifiesAndBecomesReady() async throws {
        let store = makeStore()
        store.start()
        XCTAssertEqual(store.state, .downloading(progress: 0))
        try await waitUntil { store.state == .ready }
        XCTAssertEqual(try Data(contentsOf: store.url(for: "model.safetensors")), modelData)
        XCTAssertEqual(try Data(contentsOf: store.url(for: "voices.npz")), voicesData)
        XCTAssertEqual(downloader.requested, [modelURL, voicesURL])
    }

    func testStartWithFilesPresentIsReadyWithoutDownloading() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try modelData.write(to: store.url(for: "model.safetensors"))
        try voicesData.write(to: store.url(for: "voices.npz"))
        store.start()
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(downloader.requested, [])
    }

    func testChecksumMismatchFailsAndKeepsNoFile() async throws {
        let store = makeStore(modelChecksum: String(repeating: "0", count: 64))
        store.start()
        try await waitUntil { if case .failed = store.state { return true } else { return false } }
        guard case let .failed(message) = store.state else { return XCTFail() }
        XCTAssertTrue(message.contains("model.safetensors"), message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: "model.safetensors").path))
    }

    func testFailedDownloadCanBeRetried() async throws {
        let store = makeStore()
        downloader.error = URLError(.notConnectedToInternet)
        store.start()
        try await waitUntil { if case .failed = store.state { return true } else { return false } }
        downloader.error = nil
        store.download()
        try await waitUntil { store.state == .ready }
    }

    func testRemoveDeletesTheFiles() async throws {
        let store = makeStore()
        store.start()
        try await waitUntil { store.state == .ready }
        store.remove()
        XCTAssertEqual(store.state, .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testTotalBytesAndStatusText() {
        let store = makeStore()
        XCTAssertEqual(store.totalBytes, Int64(modelData.count + voicesData.count))
        XCTAssertEqual(KokoroModelStore.State.notDownloaded.statusText(totalBytes: 0), "Not downloaded")
        XCTAssertEqual(KokoroModelStore.State.downloading(progress: 0.427).statusText(totalBytes: 0), "Downloading… 42%")
        XCTAssertEqual(KokoroModelStore.State.failed("x").statusText(totalBytes: 0), "Download failed")
        XCTAssertTrue(KokoroModelStore.State.ready.statusText(totalBytes: 190_000_000).hasPrefix("Ready ("))
    }

    func testShippedAssetsArePinned() {
        XCTAssertEqual(KokoroModelAssets.all.map(\.fileName), ["kokoro-v1_0-fp16.safetensors", "voices.npz"])
        XCTAssertEqual(KokoroModelAssets.all.map(\.byteCount), [163_587_908, 26_645_914])
        XCTAssertTrue(KokoroModelAssets.all.allSatisfy {
            $0.url.absoluteString.hasPrefix("https://github.com/buemura/audra-models/releases/download/kokoro-model-v1/")
                && $0.sha256.count == 64
        })
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter KokoroModelStoreTests`
Expected: compile error `cannot find type 'ModelDownloading' in scope`.

- [ ] **Step 3: Implement the store**

Create `Sources/AudraCore/Kokoro/KokoroModelStore.swift`:

```swift
import CryptoKit
import Foundation

/// Downloads a file to a temporary location (which the caller moves), reporting progress 0…1.
public protocol ModelDownloading: Sendable {
    func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

/// Keeps the Kokoro model files in Application Support: downloads and verifies them, or removes them.
@MainActor
public final class KokoroModelStore: ObservableObject {
    public enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)

        /// Short status for Settings, e.g. "Downloading… 42%".
        public func statusText(totalBytes: Int64) -> String {
            switch self {
            case .notDownloaded:
                return "Not downloaded"
            case let .downloading(progress):
                return "Downloading… \(Int((progress * 100).rounded(.down)))%"
            case .ready:
                return "Ready (\(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)))"
            case .failed:
                return "Download failed"
            }
        }
    }

    public struct Asset: Equatable, Sendable {
        public let fileName: String
        public let url: URL
        /// Lowercase hex SHA-256 of the file.
        public let sha256: String
        public let byteCount: Int64

        public init(fileName: String, url: URL, sha256: String, byteCount: Int64) {
            self.fileName = fileName
            self.url = url
            self.sha256 = sha256
            self.byteCount = byteCount
        }
    }

    enum Failure: LocalizedError {
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case let .checksumMismatch(fileName): return "\(fileName) is corrupt (checksum mismatch)"
            }
        }
    }

    @Published public private(set) var state: State = .notDownloaded
    public let directory: URL
    private let assets: [Asset]
    private let downloader: any ModelDownloading
    private var downloadTask: Task<Void, Never>?

    public init(directory: URL, assets: [Asset], downloader: any ModelDownloading) {
        self.directory = directory
        self.assets = assets
        self.downloader = downloader
    }

    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    public var totalBytes: Int64 {
        assets.reduce(0) { $0 + $1.byteCount }
    }

    /// On launch: ready if every file is present, otherwise start downloading.
    public func start() {
        let present = assets.allSatisfy { FileManager.default.fileExists(atPath: url(for: $0.fileName).path) }
        if present {
            state = .ready
        } else {
            download()
        }
    }

    /// Downloads whatever is missing. Also used to retry after a failure.
    public func download() {
        guard downloadTask == nil, state != .ready else { return }
        state = .downloading(progress: 0)
        downloadTask = Task { [weak self] in
            await self?.performDownload()
            self?.downloadTask = nil
        }
    }

    /// Deletes the files. They are downloaded again on the next launch, or with `download()`.
    public func remove() {
        downloadTask?.cancel()
        downloadTask = nil
        try? FileManager.default.removeItem(at: directory)
        state = .notDownloaded
    }

    private func performDownload() async {
        let total = Double(max(totalBytes, 1))
        var completed: Int64 = 0
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for asset in assets {
                let destination = url(for: asset.fileName)
                if FileManager.default.fileExists(atPath: destination.path) {
                    completed += asset.byteCount
                    continue
                }
                let done = Double(completed)
                let temporary = try await downloader.download(asset.url) { fraction in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = .downloading(progress: (done + fraction * Double(asset.byteCount)) / total)
                    }
                }
                try Task.checkCancellation()
                guard try await Self.sha256(of: temporary) == asset.sha256 else {
                    try? FileManager.default.removeItem(at: temporary)
                    throw Failure.checksumMismatch(asset.fileName)
                }
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                completed += asset.byteCount
            }
            try Task.checkCancellation()
            state = .ready
        } catch {
            // After remove(), the cancelled download must not overwrite the state.
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private nonisolated static func sha256(of file: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
```

Create `Sources/AudraCore/Kokoro/KokoroModelAssets.swift`:

```swift
import Foundation

/// The model files the app downloads, built by scripts/prepare-kokoro-assets.py and published as
/// release `kokoro-model-v1` of the public repo buemura/audra-models.
public enum KokoroModelAssets {
    public static let modelFileName = "kokoro-v1_0-fp16.safetensors"
    public static let voicesFileName = "voices.npz"

    private static let releaseURL = URL(string: "https://github.com/buemura/audra-models/releases/download/kokoro-model-v1/")!

    public static let all: [KokoroModelStore.Asset] = [
        KokoroModelStore.Asset(
            fileName: modelFileName,
            url: releaseURL.appendingPathComponent(modelFileName),
            sha256: "67d4b879ce0f0bc6d30169cca8dc424f192cbed5be811078d8ef7c4a34a34b1f",
            byteCount: 163_587_908
        ),
        KokoroModelStore.Asset(
            fileName: voicesFileName,
            url: releaseURL.appendingPathComponent(voicesFileName),
            sha256: "9555acb689b3856bb58215b42e0ce65bcc228e1b6286df9c7d92d205e795d3dc",
            byteCount: 26_645_914
        ),
    ]
}
```

- [ ] **Step 4: Implement the URLSession downloader**

Create `Sources/AudraCore/Kokoro/URLSessionModelDownloader.swift`:

```swift
import Foundation

/// Downloads with URLSession. A failed download keeps its resume data, so a retry in the same
/// session continues where it stopped.
public final class URLSessionModelDownloader: NSObject, ModelDownloading, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct Pending {
        let url: URL
        let continuation: CheckedContinuation<URL, Error>
        let progress: @Sendable (Double) -> Void
    }

    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]
    private var resumeData: [URL: Data] = [:]
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    public override init() {
        super.init()
    }

    public func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            let task = resumeData.removeValue(forKey: url).map { session.downloadTask(withResumeData: $0) }
                ?? session.downloadTask(with: url)
            pending[task.taskIdentifier] = Pending(url: url, continuation: continuation, progress: progress)
            lock.unlock()
            task.resume()
        }
    }

    private func takePending(_ task: URLSessionTask) -> Pending? {
        lock.lock()
        defer { lock.unlock() }
        return pending.removeValue(forKey: task.taskIdentifier)
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        lock.lock()
        let progress = pending[downloadTask.taskIdentifier]?.progress
        lock.unlock()
        progress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let pending = takePending(downloadTask) else { return }
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            pending.continuation.resume(throwing: URLError(.badServerResponse))
            return
        }
        // `location` is deleted when this method returns, so move it now.
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            pending.continuation.resume(returning: destination)
        } catch {
            pending.continuation.resume(throwing: error)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let pending = takePending(task) else { return }
        if let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            lock.lock()
            resumeData[pending.url] = data
            lock.unlock()
        }
        pending.continuation.resume(throwing: error)
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test`
Expected: all pass, including 7 new `KokoroModelStoreTests`.

- [ ] **Step 6: Commit**

```bash
git add Sources/AudraCore/Kokoro Tests/AudraCoreTests
git commit -m "feat: add Kokoro model store with verified download

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Package restructure, vendored engines and eSpeak phonemizer

This task switches the project to macOS 15 / Apple Silicon and an `xcodebuild`-based build. MLX's Metal shaders only compile under Xcode. It vendors KokoroSwift (with two patches) and the prebuilt eSpeak NG framework, and adds the `AudraKokoro` target with its first unit, `ESpeakPhonemizer`.

**Files:**
- Create: `Packages/KokoroSwift/` (vendored), `Packages/KokoroSwift/VENDORED.md`
- Create: `Packages/ESpeakNG/` (vendored), `Packages/ESpeakNG/Package.swift`, `Packages/ESpeakNG/VENDORED.md`
- Modify: `Package.swift`
- Create: `Sources/AudraKokoro/ESpeakPhonemizer.swift`
- Test: `Tests/AudraKokoroTests/ESpeakPhonemizerTests.swift`
- Modify: `scripts/build-app.sh`, `Makefile`, `Support/Info.plist`

**Interfaces:**
- Consumes: `Phonemizer` (Task 5).
- Produces:
  - SwiftPM products `KokoroSwift` (with `KokoroTTS.generateAudio(voice: MLXArray, phonemes: String, speed: Float) throws -> [Float]`) and `ESpeakNG` (C module).
  - Target `AudraKokoro` containing `final class ESpeakPhonemizer: Phonemizer` with `init(language: String) throws` (eSpeak tags `"es"`, `"pt-br"`, `"fr-fr"`, `"it"`, `"hi"`, `"ja"`, `"cmn"`) and `enum Failure: Error, Equatable { case dataNotFound, initializationFailed, languageNotFound(String) }`.
  - `make test` runs all tests with `xcodebuild`.

- [ ] **Step 1: Vendor KokoroSwift**

```bash
SRC="$(mktemp -d)/kokoro-ios"
git clone --quiet https://github.com/mlalma/kokoro-ios.git "$SRC"
git -C "$SRC" checkout --quiet 4d6d1d8ff8cd012014180c9cd4cf0151e7682354
mkdir -p Packages/KokoroSwift
cp -R "$SRC/Package.swift" "$SRC/LICENSE" "$SRC/Resources" "$SRC/Sources" Packages/KokoroSwift/
```

In `Packages/KokoroSwift/Package.swift`, delete the test target (its sources weren't copied):

```swift
    .testTarget(
      name: "KokoroSwiftTests",
      dependencies: ["KokoroSwift"]
    ),
```

- [ ] **Step 2: Patch KokoroSwift: phoneme input**

In `Packages/KokoroSwift/Sources/KokoroSwift/TTSEngine/KokoroTTS.swift`, replace:

```swift
  public func generateAudio(voice: MLXArray, language: Language, text: String, speed: Float = 1.0) throws -> ([Float], [MToken]?) {
    // Update language if it has changed
    try updateLanguageIfNeeded(language)
```

with:

```swift
  /// Generates audio for text already converted to Kokoro phonemes, skipping G2P.
  /// (Audra patch: the app phonemizes non-English languages itself.)
  public func generateAudio(voice: MLXArray, phonemes: String, speed: Float = 1.0) throws -> [Float] {
    phonemeInput = phonemes
    defer { phonemeInput = nil }
    return try generateAudio(voice: voice, language: .none, text: "", speed: speed).0
  }

  /// Set while `generateAudio(voice:phonemes:speed:)` runs.
  private var phonemeInput: String?

  public func generateAudio(voice: MLXArray, language: Language, text: String, speed: Float = 1.0) throws -> ([Float], [MToken]?) {
    // Update language if it has changed
    if phonemeInput == nil { try updateLanguageIfNeeded(language) }
```

and replace:

```swift
    let (phonemizedText, tokenArray) = try phonemizeText(text)
```

with:

```swift
    let (phonemizedText, tokenArray) = try phonemeInput.map { ($0, nil) } ?? phonemizeText(text)
```

- [ ] **Step 3: Patch KokoroSwift: tokenize per Unicode scalar**

In `Packages/KokoroSwift/Sources/KokoroSwift/TextProcessing/Tokenizer.swift`, replace:

```swift
    return text
      .map { vocab[String($0)] }
      .filter { $0 != nil }
      .map { $0! }
```

with:

```swift
    // One token per Unicode scalar, like Kokoro's Python tokenizer. (Audra patch: mapping
    // Characters looked up clusters such as "ɐ̃" — vowel + combining tilde — which aren't in the
    // vocabulary, silently dropping Portuguese and French nasal vowels.)
    return text.unicodeScalars.compactMap { vocab[String($0)] }
```

Create `Packages/KokoroSwift/VENDORED.md`:

```markdown
# Vendored KokoroSwift

Source: https://github.com/mlalma/kokoro-ios at 4d6d1d8ff8cd012014180c9cd4cf0151e7682354 (MIT, see LICENSE).
Copied: Package.swift (test target removed), LICENSE, Resources/, Sources/.

Local patches:
1. `KokoroTTS.generateAudio(voice:phonemes:speed:)` — synthesize from phonemes, skipping G2P.
2. `Tokenizer.tokenize` maps Unicode scalars instead of Characters (fixes dropped nasal vowels).
```

- [ ] **Step 4: Vendor the eSpeak NG framework**

```bash
SRC="$(mktemp -d)/eSpeakNGSwift"
git clone --quiet https://github.com/mlalma/eSpeakNGSwift.git "$SRC"
git -C "$SRC" checkout --quiet a2b2fbb2efca20e1273a7399e3d578d67ca8940d
mkdir -p Packages/ESpeakNG/ESpeakNG.xcframework
cp -R "$SRC/Frameworks/ESpeakNG.xcframework/macos-arm64_x86_64" Packages/ESpeakNG/ESpeakNG.xcframework/
cp "$SRC/LICENSE" Packages/ESpeakNG/LICENSE
# Keep only the macOS library in the xcframework manifest.
python3 - "$SRC/Frameworks/ESpeakNG.xcframework/Info.plist" Packages/ESpeakNG/ESpeakNG.xcframework/Info.plist <<'EOF'
import plistlib, sys
info = plistlib.load(open(sys.argv[1], "rb"))
info["AvailableLibraries"] = [lib for lib in info["AvailableLibraries"] if lib["SupportedPlatform"] == "macos"]
plistlib.dump(info, open(sys.argv[2], "wb"))
EOF
# Keep only the dictionaries we use (+ English, which eSpeak switches to for English words).
FRAMEWORK=Packages/ESpeakNG/ESpeakNG.xcframework/macos-arm64_x86_64/ESpeakNG.framework
DATA="$FRAMEWORK/Versions/A/Resources/espeak-ng-data.bundle/espeak-ng-data"
find "$DATA" -maxdepth 1 -name '*_dict' ! -name en_dict ! -name es_dict ! -name pt_dict ! -name fr_dict \
  ! -name it_dict ! -name hi_dict ! -name ja_dict ! -name cmn_dict -delete
codesign --force --sign - "$FRAMEWORK"   # resources changed, so re-sign
ls "$DATA" | grep _dict | tr '\n' ' '; echo; du -sh Packages/ESpeakNG
```

Expected: `cmn_dict en_dict es_dict fr_dict hi_dict it_dict ja_dict pt_dict` and about 6 MB.

Create `Packages/ESpeakNG/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ESpeakNG",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ESpeakNG", targets: ["ESpeakNG"]),
    ],
    targets: [
        .binaryTarget(name: "ESpeakNG", path: "ESpeakNG.xcframework"),
    ]
)
```

Create `Packages/ESpeakNG/VENDORED.md`:

```markdown
# Vendored eSpeak NG

`ESpeakNG.xcframework` is eSpeak NG 1.52.0 (GPL-3.0-or-later, see LICENSE) as prebuilt by
https://github.com/mlalma/eSpeakNGSwift at a2b2fbb2efca20e1273a7399e3d578d67ca8940d.
eSpeak NG source: https://github.com/espeak-ng/espeak-ng/tree/1.52.0

Changes: macOS slice only; `espeak-ng-data` keeps only the en, es, pt, fr, it, hi, ja and cmn
dictionaries; framework re-signed ad hoc.
```

- [ ] **Step 5: Restructure Package.swift**

Replace `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Audra",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Audra", targets: ["AudraApp"]),
        .library(name: "AudraCore", targets: ["AudraCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.2"),
        .package(url: "https://github.com/mlalma/MisakiSwift", exact: "1.0.6"),
        .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6"),
        .package(path: "Packages/KokoroSwift"),
        .package(path: "Packages/ESpeakNG"),
    ],
    targets: [
        .target(name: "AudraCore"),
        // Everything that links MLX, MisakiSwift or eSpeak NG.
        .target(
            name: "AudraKokoro",
            dependencies: [
                "AudraCore",
                .product(name: "KokoroSwift", package: "KokoroSwift"),
                .product(name: "ESpeakNG", package: "ESpeakNG"),
                .product(name: "MisakiSwift", package: "MisakiSwift"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary"),
            ]
        ),
        .executableTarget(
            name: "AudraApp",
            dependencies: ["AudraCore", "AudraKokoro", "KeyboardShortcuts"],
            // The app bundle keeps the package frameworks (MLX, KokoroSwift, …) in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "AudraCoreTests", dependencies: ["AudraCore"]),
        .testTarget(name: "AudraKokoroTests", dependencies: ["AudraKokoro"]),
    ],
    swiftLanguageModes: [.v5]
)
```

In `Makefile`, change the `build` comment to `## Build "build/Audra.app" (Apple Silicon, ad-hoc signed)` and replace the `test` recipe with:

```make
## Run all tests with xcodebuild (MLX needs the Metal toolchain). ONLY=Target/TestClass runs a subset.
## The bundle path lets package resources (Misaki dictionaries, Kokoro config) load outside an app.
test:
	TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH="$(CURDIR)/build/DerivedData/Build/Products/Debug" \
	xcodebuild test -scheme Audra-Package -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build/DerivedData -quiet $(if $(ONLY),-only-testing:$(ONLY))
```

Without `TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH`, MisakiSwift and KokoroSwift crash in tests with `unable to find bundle named …`. The app doesn't need it, because their bundles sit in `Contents/Resources`.

- [ ] **Step 6: Write the failing eSpeak test**

Create `Tests/AudraKokoroTests/ESpeakPhonemizerTests.swift`:

```swift
import XCTest
@testable import AudraKokoro

final class ESpeakPhonemizerTests: XCTestCase {
    func testMatchesMisakiReferenceOutput() throws {
        // Reference outputs of misaki's EspeakG2P (Kokoro v1.0) with eSpeak NG 1.52.0.
        let cases: [(String, String, String)] = [
            ("es", "Hola, ¿cómo estás?", "ˈola, ¿kˈomo estˈas?"),
            ("es", "Tengo 3 gatos.", "tˈɛŋɡo tɾˈes ɣˈatos."),
            ("pt-br", "Olá, tudo bem?", "olˈa, tˈudʊ bˈAŋ?"),
            ("pt-br", "Eu tenho 3 gatos.", "eʊ tˌeɲʊ trˈez ɡˈatʊs."),
            ("fr-fr", "Bonjour, comment ça va ?", "bɔ̃ʒˈuʁ, kɔmˌɑ̃ sa vˈa ?"),
            ("it", "Ciao, come stai?", "ʧˈao, kˌome stˈaj?"),
            ("hi", "नमस्ते, आप कैसे हैं?", "nəmˈʌsteː, ˌaːp kˈɛːseː hɛ̃?"),
        ]
        for (language, text, phonemes) in cases {
            XCTAssertEqual(try ESpeakPhonemizer(language: language).phonemize(text), phonemes, "\(language): \(text)")
        }
    }

    func testPhonemizersForDifferentLanguagesCanBeInterleaved() throws {
        let spanish = try ESpeakPhonemizer(language: "es")
        let italian = try ESpeakPhonemizer(language: "it")
        XCTAssertEqual(try spanish.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
        XCTAssertEqual(try italian.phonemize("Ciao, come stai?"), "ʧˈao, kˌome stˈaj?")
        XCTAssertEqual(try spanish.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
    }

    func testJapaneseAndChineseFallbacksProduceOutput() throws {
        XCTAssertFalse(try ESpeakPhonemizer(language: "ja").phonemize("こんにちは").isEmpty)
        XCTAssertFalse(try ESpeakPhonemizer(language: "cmn").phonemize("你好").isEmpty)
    }
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `make test ONLY=AudraKokoroTests/ESpeakPhonemizerTests 2>&1 | tail -20`
Expected: build failure, `cannot find 'ESpeakPhonemizer' in scope`. If xcodebuild reports a missing Metal toolchain instead, run `xcodebuild -downloadComponent MetalToolchain` first. The first run also resolves packages and compiles MLX, which takes a few minutes.

- [ ] **Step 8: Implement**

Create `Sources/AudraKokoro/ESpeakPhonemizer.swift`:

```swift
import ESpeakNG
import Foundation
import AudraCore

/// eSpeak NG phonemes post-processed for Kokoro the way misaki's `EspeakG2P` does, punctuation kept.
/// eSpeak is a process-wide C library, so every call goes through one lock.
public final class ESpeakPhonemizer: Phonemizer, @unchecked Sendable {
    public enum Failure: Error, Equatable {
        case dataNotFound
        case initializationFailed
        case languageNotFound(String)
    }

    private static let lock = NSLock()
    /// Guarded by `lock`.
    private static var initialized = false

    private let language: String

    /// - Parameter language: eSpeak language tag, e.g. "es", "pt-br", "fr-fr", "it", "hi", "ja", "cmn".
    public init(language: String) throws {
        self.language = language
        try Self.lock.withLock {
            try Self.initializeIfNeeded()
            guard Self.select(language: language) else { throw Failure.languageNotFound(language) }
        }
    }

    /// misaki's `E2M` for `EspeakG2P` (Kokoro v1.0).
    private static let replacements: [(String, String)] = [
        ("a^ɪ", "I"), ("a^ʊ", "W"), ("d^z", "ʣ"), ("d^ʒ", "ʤ"), ("e^ɪ", "A"), ("o^ʊ", "O"), ("ə^ʊ", "Q"),
        ("s^s", "S"), ("t^s", "ʦ"), ("t^ʃ", "ʧ"), ("ɔ^ɪ", "Y"),
    ]

    /// phonemizer's default punctuation marks; they are kept in the output like misaki does.
    private static let marks = try! NSRegularExpression(pattern: "\\s*[;:,.!?¡¿—…\"«»“”(){}\\[\\]]+\\s*")

    public func phonemize(_ text: String) throws -> String {
        // misaki maps «» to curly quotes and parentheses to «», then back at the end.
        let prepared = text
            .replacingOccurrences(of: "«", with: "“").replacingOccurrences(of: "»", with: "”")
            .replacingOccurrences(of: "(", with: "«").replacingOccurrences(of: ")", with: "»")
        let ns = prepared as NSString
        var output = ""
        var cursor = 0
        try Self.lock.withLock {
            guard Self.select(language: language) else { throw Failure.languageNotFound(language) }
            for match in Self.marks.matches(in: prepared, range: NSRange(location: 0, length: ns.length)) {
                output += Self.rawPhonemes(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
                let mark = ns.substring(with: match.range)
                if mark.first?.isWhitespace == true, !output.isEmpty, output.last != " " { output += " " }
                output += mark.trimmingCharacters(in: .whitespaces)
                if mark.last?.isWhitespace == true { output += " " }
                cursor = match.range.location + match.range.length
            }
            output += Self.rawPhonemes(ns.substring(from: cursor))
        }
        var result = output.trimmingCharacters(in: .whitespaces)
        for (old, new) in Self.replacements {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
            .replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "«", with: "(").replacingOccurrences(of: "»", with: ")")
    }

    // MARK: - eSpeak (call with `lock` held)

    /// `espeak-ng-data` ships inside the vendored ESpeakNG.framework.
    private static func initializeIfNeeded() throws {
        guard !initialized else { return }
        guard let dataPath = Bundle(identifier: "com.kokoro.espeakng")?
            .url(forResource: "espeak-ng-data", withExtension: "bundle")?.path
        else { throw Failure.dataNotFound }
        guard espeak_Initialize(AUDIO_OUTPUT_RETRIEVAL, 0, dataPath, 0) > 0 else { throw Failure.initializationFailed }
        initialized = true
    }

    /// Selects the voice for a language tag, as phonemizer does.
    private static func select(language: String) -> Bool {
        language.withCString { tag in
            var properties = espeak_VOICE()
            properties.languages = tag
            return espeak_SetVoiceByProperties(&properties) == EE_OK
        }
    }

    /// eSpeak IPA for text without punctuation, ties written as "^", clauses joined by spaces.
    private static func rawPhonemes(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        // espeakPHONEMES_IPA | espeakPHONEMES_TIE, with U+0361 as the tie character.
        let mode = Int32(0x02 | 0x80 | (0x0361 << 8))
        var clauses: [String] = []
        text.withCString { cString in
            var pointer: UnsafeRawPointer? = UnsafeRawPointer(cString)
            while pointer != nil {
                guard let phonemes = espeak_TextToPhonemes(&pointer, espeakCHARS_UTF8, mode) else { break }
                clauses.append(String(cString: phonemes))
            }
        }
        return clauses.joined(separator: " ")
            // Language-switch flags such as "(en)", removed like phonemizer's "remove-flags".
            .replacingOccurrences(of: "\\(.+?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{0361}", with: "^")
            .trimmingCharacters(in: .whitespaces)
    }
}
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `make test ONLY=AudraKokoroTests/ESpeakPhonemizerTests 2>&1 | grep -E "Executed|error|failed"`
Expected: `Executed 3 tests, with 0 failures`.

- [ ] **Step 10: Switch the app build to xcodebuild**

Replace `scripts/build-app.sh` with:

```bash
#!/usr/bin/env bash
# Builds an Apple Silicon, ad-hoc-signed "build/Audra.app".
# xcodebuild (not swift build) is required: it compiles MLX's Metal shaders.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Audra.app"
DERIVED="build/DerivedData"
PRODUCTS="$DERIVED/Build/Products/Release"

xcodebuild build -scheme Audra -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DERIVED" -quiet

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCTS/Audra" "$APP/Contents/MacOS/Audra"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Package frameworks: MLX, KokoroSwift, MisakiSwift, eSpeak NG, …
find "$PRODUCTS" "$PRODUCTS/PackageFrameworks" -maxdepth 1 -name '*.framework' -exec cp -R {} "$APP/Contents/Frameworks/" \;
# SwiftPM resource bundles: MLX's Metal library, Kokoro config, Misaki dictionaries, KeyboardShortcuts' localizations.
find "$PRODUCTS" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

codesign --force --deep --sign - "$APP"
echo "Built $APP"
```

In `Support/Info.plist`, change `LSMinimumSystemVersion` from `14.0` to `15.0`.

- [ ] **Step 11: Verify everything builds and passes**

Run: `make test 2>&1 | tail -5`, then `./scripts/build-app.sh && ls "build/Audra.app/Contents/Frameworks"`
Expected: tests pass (all Core tests plus `ESpeakPhonemizerTests`); the app builds; `Frameworks` lists `Cmlx.framework`, `ESpeakNG.framework`, `KokoroSwift.framework`, `MLX.framework` and `MisakiSwift.framework`, among others.

- [ ] **Step 12: Commit**

```bash
git add Package.swift Package.resolved Packages Sources/AudraKokoro Tests/AudraKokoroTests scripts/build-app.sh Makefile Support/Info.plist
git commit -m "build: vendor KokoroSwift and eSpeak NG, add AudraKokoro target

Requires macOS 15 on Apple Silicon and builds with xcodebuild (MLX Metal shaders).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Model assets: build and publish

**Files:**
- Create: `scripts/prepare-kokoro-assets.py`

**Interfaces:**
- Produces: `build/kokoro-assets/kokoro-v1_0-fp16.safetensors` and `build/kokoro-assets/voices.npz`, matching the sizes and checksums in Global Constraints and `KokoroModelAssets` (Task 12). The release `kokoro-model-v1` on the public repo `buemura/audra-models` serves them.

- [ ] **Step 1: Add the script**

Create `scripts/prepare-kokoro-assets.py` (then `chmod +x scripts/prepare-kokoro-assets.py`):

```python
#!/usr/bin/env python3
"""Builds the Kokoro model files the app downloads (published as a GitHub Release asset).

Usage:
    uv run --python 3.12 --with numpy --with safetensors --with torch --with huggingface_hub \
        scripts/prepare-kokoro-assets.py build/kokoro-assets

Outputs, byte-for-byte reproducible:
    kokoro-v1_0-fp16.safetensors  KokoroSwift-format weights, converted to float16
    voices.npz                    style vectors for the voices in KokoroVoiceCatalog
and prints each file's size and SHA-256 for KokoroModelAssets.swift.
"""
import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
import torch
from huggingface_hub import hf_hub_download
from safetensors.numpy import load, save

# KokoroSwift-format float32 weights (Apache-2.0, converted from hexgrad/Kokoro-82M by the KokoroSwift author).
MODEL_URL = ("https://media.githubusercontent.com/media/mlalma/KokoroTestApp/"
             "9dcd3b06468a3c1ecee6d09a33ca687c8e708566/Resources/kokoro-v1_0.safetensors")
MODEL_SHA256 = "4e9ecdf03b8b6cf906070390237feda473dc13327cb8d56a43deaa374c02acd8"
VOICES_REPO = "hexgrad/Kokoro-82M"
VOICES_REVISION = "f3ff3571791e39611d31c381e3a41a3af07b4987"

# Must match KokoroVoiceCatalog.swift.
VOICES = """
af_heart af_bella af_nicole af_aoede af_kore af_sarah af_nova af_sky af_alloy af_jessica af_river
am_michael am_fenrir am_puck am_echo am_eric am_liam am_onyx am_adam
bf_emma bf_isabella bf_alice bf_lily bm_george bm_fable bm_lewis bm_daniel
pf_dora pm_alex ef_dora em_alex ff_siwis if_sara im_nicola
hf_alpha hf_beta hm_omega hm_psi
jf_alpha jf_gongitsune jf_nezumi jf_tebukuro jm_kumo
zf_xiaobei zf_xiaoni zf_xiaoxiao zf_xiaoyi zm_yunjian zm_yunxi zm_yunxia zm_yunyang
""".split()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_model(out: Path) -> Path:
    data = urllib.request.urlopen(MODEL_URL).read()
    if sha256(data) != MODEL_SHA256:
        sys.exit("Downloaded model checksum mismatch")
    weights = load(data)
    fp16 = {name: weights[name].astype(np.float16) for name in sorted(weights)}
    path = out / "kokoro-v1_0-fp16.safetensors"
    path.write_bytes(save(fp16))
    return path


def build_voices(out: Path) -> Path:
    path = out / "voices.npz"
    # A zip with fixed timestamps so the file (and its checksum) is reproducible.
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
        for voice in VOICES:
            pt = hf_hub_download(VOICES_REPO, f"voices/{voice}.pt", revision=VOICES_REVISION)
            array = torch.load(pt, weights_only=True).numpy().astype(np.float32)
            buffer = io.BytesIO()
            np.save(buffer, array)
            archive.writestr(zipfile.ZipInfo(f"{voice}.npy", date_time=(1980, 1, 1, 0, 0, 0)), buffer.getvalue())
    return path


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for path in (build_model(out), build_voices(out)):
        data = path.read_bytes()
        print(f"{path.name}\tsize={len(data)}\tsha256={sha256(data)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Build the assets and check they are byte-identical to the pinned ones**

Run:

```bash
uv run --python 3.12 --with numpy --with safetensors --with torch --with huggingface_hub \
    scripts/prepare-kokoro-assets.py build/kokoro-assets
```

Expected output (exactly):

```
kokoro-v1_0-fp16.safetensors	size=163587908	sha256=67d4b879ce0f0bc6d30169cca8dc424f192cbed5be811078d8ef7c4a34a34b1f
voices.npz	size=26645914	sha256=9555acb689b3856bb58215b42e0ce65bcc228e1b6286df9c7d92d205e795d3dc
```

If either value differs, stop and report it. Don't edit `KokoroModelAssets`: the script is meant to be reproducible.

- [ ] **Step 3: Commit the script**

```bash
git add scripts/prepare-kokoro-assets.py
git commit -m "build: add script that builds the Kokoro model assets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Publish (ask the user first)**

This creates a **public** GitHub repository and uploads 190 MB to it. Ask the user for explicit confirmation before running it. If they decline, skip to Step 6; the app then falls back to system voices until the files are published.

```bash
REPO_DIR="$(mktemp -d)"
cat > "$REPO_DIR/README.md" <<'EOF'
# Audra models

Model files downloaded by the Audra macOS app on first launch. See the releases.

- `kokoro-v1_0-fp16.safetensors` — Kokoro-82M v1.0 (https://huggingface.co/hexgrad/Kokoro-82M, Apache-2.0),
  in KokoroSwift's weight layout, converted to float16.
- `voices.npz` — Kokoro-82M v1.0 voice style vectors (Apache-2.0).

Built reproducibly by `scripts/prepare-kokoro-assets.py` in the Audra repository.
EOF
git -C "$REPO_DIR" init --quiet -b main
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit --quiet -m "Add README"
gh repo create buemura/audra-models --public --source="$REPO_DIR" --push \
    --description "Model files downloaded by Audra (Kokoro-82M, Apache-2.0)"
gh release create kokoro-model-v1 --repo buemura/audra-models --title "Kokoro model v1" \
    --notes "Kokoro-82M v1.0 (Apache-2.0): fp16 weights in KokoroSwift layout and voice styles." \
    build/kokoro-assets/kokoro-v1_0-fp16.safetensors build/kokoro-assets/voices.npz
```

- [ ] **Step 5: Verify the published files**

```bash
for f in kokoro-v1_0-fp16.safetensors voices.npz; do
  curl -sL "https://github.com/buemura/audra-models/releases/download/kokoro-model-v1/$f" | shasum -a 256
done
```

Expected: `67d4b879…b1f` and `9555acb6…3dc` (the full values in Global Constraints).

- [ ] **Step 6: Install the assets locally for development**

Copy the files where the app keeps them. Task 15's engine test uses them, and the app skips the download:

```bash
mkdir -p ~/Library/Application\ Support/Audra/Kokoro
cp build/kokoro-assets/kokoro-v1_0-fp16.safetensors build/kokoro-assets/voices.npz ~/Library/Application\ Support/Audra/Kokoro/
```

---

### Task 15: English phonemizer, MLX engine and phonemizer registry

**Files:**
- Create: `Sources/AudraKokoro/EnglishPhonemizer.swift`
- Create: `Sources/AudraKokoro/MLXKokoroEngine.swift`
- Create: `Sources/AudraKokoro/KokoroPhonemizers.swift`
- Test: `Tests/AudraKokoroTests/EnglishPhonemizerTests.swift`
- Test: `Tests/AudraKokoroTests/KokoroPhonemizersTests.swift`
- Test: `Tests/AudraKokoroTests/MLXKokoroEngineTests.swift`

**Interfaces:**
- Consumes: `KokoroEngine`, `KokoroEngineError` (Task 10); `Phonemizer`, `FallbackPhonemizer` (Task 5); `JapanesePhonemizer` (Task 7); `ChinesePhonemizer` (Task 9); `KokoroLanguage` (Task 3); `KokoroModelAssets` (Task 12); `ESpeakPhonemizer` and patched `KokoroTTS.generateAudio(voice:phonemes:speed:)` (Task 13).
- Produces:
  - `final class EnglishPhonemizer: Phonemizer` with `init(british: Bool)`.
  - `actor MLXKokoroEngine: KokoroEngine` with `init(modelURL: URL, voicesURL: URL, idleTimeout: Duration = .seconds(600))` and `func unload()`.
  - `enum KokoroPhonemizers` with `@MainActor static func phonemizer(for: KokoroLanguage) -> (any Phonemizer)?`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraKokoroTests/EnglishPhonemizerTests.swift`:

```swift
import XCTest
@testable import AudraKokoro

final class EnglishPhonemizerTests: XCTestCase {
    func testAmericanEnglishMatchesMisaki() throws {
        XCTAssertEqual(try EnglishPhonemizer(british: false).phonemize("Hello world!"), "həlˈO wˈɜɹld!")
    }

    func testBritishEnglishProducesPhonemes() throws {
        XCTAssertFalse(try EnglishPhonemizer(british: true).phonemize("Hello world!").isEmpty)
    }
}
```

Create `Tests/AudraKokoroTests/KokoroPhonemizersTests.swift`:

```swift
import AudraCore
import XCTest
@testable import AudraKokoro

@MainActor
final class KokoroPhonemizersTests: XCTestCase {
    func testEveryKokoroLanguageHasAPhonemizer() {
        for language in KokoroLanguage.allCases {
            XCTAssertNotNil(KokoroPhonemizers.phonemizer(for: language), "\(language)")
        }
    }

    func testPhonemizersAreReusedAndUseTheRightLanguage() throws {
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .japanese)?.phonemize("学校の先生"), "ɡaʔkoː no seɴseː")
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .spanish)?.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .italian)?.phonemize("Ciao, come stai?"), "ʧˈao, kˌome stˈaj?")
        // Back to Spanish after Italian: eSpeak's global voice must be reselected.
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .spanish)?.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
    }
}
```

Create `Tests/AudraKokoroTests/MLXKokoroEngineTests.swift`:

```swift
import AudraCore
import XCTest
@testable import AudraKokoro

final class MLXKokoroEngineTests: XCTestCase {
    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Audra/Kokoro", isDirectory: true)
    }

    func testMissingModelIsUnavailable() async {
        let engine = MLXKokoroEngine(
            modelURL: URL(fileURLWithPath: "/nonexistent/model.safetensors"),
            voicesURL: URL(fileURLWithPath: "/nonexistent/voices.npz")
        )
        do {
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "af_heart", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }

    /// Needs the model files installed (Task 14, Step 6).
    func testSynthesizesSpeech() async throws {
        let model = modelDirectory.appendingPathComponent(KokoroModelAssets.modelFileName)
        let voices = modelDirectory.appendingPathComponent(KokoroModelAssets.voicesFileName)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: model.path), "Kokoro model not installed")
        let engine = MLXKokoroEngine(modelURL: model, voicesURL: voices)

        let samples = try await engine.synthesize(phonemes: "həlˈO wˈɜɹld!", voiceID: "af_heart", speed: 1)
        XCTAssertGreaterThan(samples.count, 12_000) // > 0.5 s at 24 kHz
        XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.05)

        do {
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "xx_nobody", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `make test ONLY=AudraKokoroTests 2>&1 | grep -E "error:" | head -5`
Expected: `cannot find 'EnglishPhonemizer' in scope` (and similar).

- [ ] **Step 3: Implement**

Create `Sources/AudraKokoro/EnglishPhonemizer.swift`:

```swift
import Foundation
import MisakiSwift
import AudraCore

/// English text → Kokoro phonemes with MisakiSwift, a port of the G2P Kokoro was trained with.
public final class EnglishPhonemizer: Phonemizer, @unchecked Sendable {
    private let g2p: EnglishG2P
    private let lock = NSLock()

    public init(british: Bool) {
        g2p = EnglishG2P(british: british)
    }

    public func phonemize(_ text: String) throws -> String {
        lock.withLock {
            // Misaki marks words it can't pronounce with "❓"; Kokoro can't voice it.
            g2p.phonemize(text: text).0.replacingOccurrences(of: "❓", with: "")
        }
    }
}
```

Create `Sources/AudraKokoro/MLXKokoroEngine.swift`:

```swift
import Foundation
import KokoroSwift
import MLX
import MLXUtilsLibrary
import AudraCore

/// Kokoro on MLX. Loads the model on first use and unloads it after `idleTimeout` without speech.
public actor MLXKokoroEngine: KokoroEngine {
    private let modelURL: URL
    private let voicesURL: URL
    private let idleTimeout: Duration
    private var tts: KokoroTTS?
    private var voices: [String: MLXArray] = [:]
    private var unloadTask: Task<Void, Never>?

    public init(modelURL: URL, voicesURL: URL, idleTimeout: Duration = .seconds(600)) {
        self.modelURL = modelURL
        self.voicesURL = voicesURL
        self.idleTimeout = idleTimeout
    }

    public func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] {
        unloadTask?.cancel()
        defer { scheduleUnload() }
        let tts = try loadedModel()
        guard let voice = voices[voiceID + ".npy"] else { throw KokoroEngineError.unavailable }
        do {
            return try tts.generateAudio(voice: voice, phonemes: phonemes, speed: speed)
        } catch KokoroTTS.KokoroTTSError.tooManyTokens {
            throw KokoroEngineError.tooManyTokens
        }
    }

    /// Frees the model's memory; it is loaded again on the next `synthesize`.
    public func unload() {
        unloadTask?.cancel()
        unloadTask = nil
        tts = nil
        voices = [:]
    }

    private func loadedModel() throws -> KokoroTTS {
        if let tts { return tts }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelURL.path), fileManager.fileExists(atPath: voicesURL.path) else {
            throw KokoroEngineError.unavailable
        }
        let loadedVoices = NpyzReader.read(fileFromPath: voicesURL) ?? [:]
        guard !loadedVoices.isEmpty else { throw KokoroEngineError.unavailable }
        let tts = KokoroTTS(modelPath: modelURL)
        self.tts = tts
        voices = loadedVoices
        return tts
    }

    private func scheduleUnload() {
        unloadTask = Task { [idleTimeout] in
            try? await Task.sleep(for: idleTimeout)
            guard !Task.isCancelled else { return }
            self.unload()
        }
    }
}
```

Create `Sources/AudraKokoro/KokoroPhonemizers.swift`:

```swift
import AudraCore

/// The phonemizer for each Kokoro language, created on first use (loading eSpeak and Misaki
/// isn't free) and then reused.
public enum KokoroPhonemizers {
    @MainActor private static var cache: [KokoroLanguage: any Phonemizer] = [:]

    @MainActor
    public static func phonemizer(for language: KokoroLanguage) -> (any Phonemizer)? {
        if let cached = cache[language] { return cached }
        guard let phonemizer = make(language) else { return nil }
        cache[language] = phonemizer
        return phonemizer
    }

    private static func make(_ language: KokoroLanguage) -> (any Phonemizer)? {
        switch language {
        case .americanEnglish: return EnglishPhonemizer(british: false)
        case .britishEnglish: return EnglishPhonemizer(british: true)
        case .brazilianPortuguese: return try? ESpeakPhonemizer(language: "pt-br")
        case .spanish: return try? ESpeakPhonemizer(language: "es")
        case .french: return try? ESpeakPhonemizer(language: "fr-fr")
        case .italian: return try? ESpeakPhonemizer(language: "it")
        case .hindi: return try? ESpeakPhonemizer(language: "hi")
        case .japanese: return FallbackPhonemizer(primary: JapanesePhonemizer(), fallback: try? ESpeakPhonemizer(language: "ja"))
        case .mandarinChinese: return FallbackPhonemizer(primary: ChinesePhonemizer(), fallback: try? ESpeakPhonemizer(language: "cmn"))
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `make test 2>&1 | tail -5`
Expected: everything passes. `MLXKokoroEngineTests.testSynthesizesSpeech` takes a few seconds; it runs rather than being skipped because Task 14 installed the model. eSpeak may log `fopen failed for data file`, which is harmless.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraKokoro Tests/AudraKokoroTests
git commit -m "feat: add MLX Kokoro engine, English phonemizer and phonemizer registry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Wire natural voices into the app

**Files:**
- Modify: `Sources/AudraApp/AppModel.swift`
- Modify: `Sources/AudraApp/SettingsView.swift`
- Modify: `Sources/AudraApp/MenuBarContent.swift`
- Modify: `Sources/AudraApp/AudraApp.swift`

**Interfaces:**
- Consumes: `RoutingSynthesizer` (Task 11), `KokoroSynthesizer`, `AVAudioEngineOutput` (Task 10), `KokoroModelStore`, `KokoroModelAssets`, `URLSessionModelDownloader` (Task 12), `KokoroVoiceCatalog` (Task 3), `MLXKokoroEngine`, `KokoroPhonemizers` (Task 15).
- Produces: `AppModel.modelStore` and `AppModel.removeNaturalVoices()`; `MenuBarContent(model:speech:settings:modelStore:)`.

The app target has no unit tests. This task is checked by building and by Task 18's manual checks.

- [ ] **Step 1: Wire the model store, engine and routing synthesizer**

Replace `Sources/AudraApp/AppModel.swift` with:

```swift
import AppKit
import Combine
import CoreGraphics
import KeyboardShortcuts
import AudraCore
import AudraKokoro

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let speech: SpeechController
    let modelStore: KokoroModelStore
    @Published private(set) var hasAccessibilityPermission = AccessibilityPermission.isGranted
    @Published private(set) var voices: [VoiceInfo]

    private let coordinator: ReadSelectionCoordinator
    private let kokoroEngine: MLXKokoroEngine
    private var permissionTimer: Timer?
    private var playerPanel: PlayerPanelController?
    private var modelStateSubscription: AnyCancellable?

    init() {
        let settings = SettingsStore()
        let modelStore = KokoroModelStore(
            directory: Self.modelDirectory,
            assets: KokoroModelAssets.all,
            downloader: URLSessionModelDownloader()
        )
        let kokoroEngine = MLXKokoroEngine(
            modelURL: modelStore.url(for: KokoroModelAssets.modelFileName),
            voicesURL: modelStore.url(for: KokoroModelAssets.voicesFileName)
        )
        let languageDetector = NLLanguageDetector()
        let synthesizer = RoutingSynthesizer(
            system: AVSpeechSynthesizerAdapter(),
            kokoro: KokoroSynthesizer(
                engine: kokoroEngine,
                output: AVAudioEngineOutput(),
                phonemizer: KokoroPhonemizers.phonemizer(for:)
            ),
            fallbackVoiceID: { text in
                Self.systemVoice(for: text, settings: settings, languageDetector: languageDetector)
            }
        )
        let speech = SpeechController(synthesizer: synthesizer)
        let availableVoices: () -> [VoiceInfo] = { [unowned modelStore] in
            Self.allVoices(modelReady: modelStore.state == .ready)
        }
        let textSource = FirstAvailableTextSource([
            AccessibilityTextSource(),
            ClipboardTextSource(
                pasteboard: SystemPasteboard(),
                copySender: CopyKeySender(),
                modifiersHeld: {
                    !CGEventSource.flagsState(.hidSystemState)
                        .intersection([.maskAlternate, .maskShift, .maskControl, .maskCommand])
                        .isEmpty
                }
            ),
        ])
        self.settings = settings
        self.speech = speech
        self.modelStore = modelStore
        self.kokoroEngine = kokoroEngine
        voices = availableVoices()
        coordinator = ReadSelectionCoordinator(
            textSource: textSource,
            speech: speech,
            settings: settings,
            languageDetector: languageDetector,
            availableVoices: availableVoices,
            onNoText: { NSSound.beep() }
        )

        KeyboardShortcuts.onKeyUp(for: .readSelection) { [weak self] in
            Task { @MainActor in await self?.toggleReading() }
        }

        if !hasAccessibilityPermission {
            AccessibilityPermission.request()
            pollForPermission()
        }

        let player = PlayerViewModel(
            speech: speech,
            settings: settings,
            availableVoices: availableVoices,
            readSelection: { [weak self] in await self?.readSelection() }
        )
        playerPanel = PlayerPanelController(viewModel: player)

        // Natural voices appear in the pickers once the model is ready. @Published emits before
        // the property changes, so use the emitted state rather than reading it back.
        modelStateSubscription = modelStore.$state
            .map { $0 == .ready }
            .removeDuplicates()
            .sink { [weak self] ready in self?.voices = Self.allVoices(modelReady: ready) }
        modelStore.start()
    }

    /// Hotkey action: stop if speaking or paused, otherwise read the selection.
    func toggleReading() async {
        if speech.state == .idle && !ensurePermission() { return }
        await coordinator.toggle()
    }

    /// "Read Selection" menu action.
    func readSelection() async {
        guard ensurePermission() else { return }
        await coordinator.readSelection()
    }

    /// Re-reads installed voices (the user may have downloaded new ones in System Settings).
    func refreshVoices() {
        voices = Self.allVoices(modelReady: modelStore.state == .ready)
    }

    /// Deletes the downloaded natural voice model and frees the memory it uses.
    func removeNaturalVoices() {
        modelStore.remove()
        let engine = kokoroEngine
        Task { await engine.unload() }
    }

    private static var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Audra/Kokoro", isDirectory: true)
    }

    /// System voices, plus the natural voices once their model is downloaded.
    private static func allVoices(modelReady: Bool) -> [VoiceInfo] {
        SystemVoices.all() + (modelReady ? KokoroVoiceCatalog.voiceInfos() : [])
    }

    /// The system voice that continues a reading Kokoro couldn't finish: the usual voice
    /// selection, with natural voices left out.
    private static func systemVoice(for text: String, settings: SettingsStore, languageDetector: NLLanguageDetector) -> String? {
        let isSystemVoice = { (id: String) in !KokoroVoiceCatalog.isKokoroVoiceID(id) }
        return VoiceSelector.selectVoice(
            detectedLanguage: settings.autoDetectLanguage ? languageDetector.detectLanguage(of: text) : nil,
            defaultVoiceID: settings.defaultVoiceID.flatMap { isSystemVoice($0) ? $0 : nil },
            languageOverrides: settings.languageVoiceOverrides.filter { isSystemVoice($0.value) },
            availableVoices: SystemVoices.all()
        )
    }

    private func ensurePermission() -> Bool {
        hasAccessibilityPermission = AccessibilityPermission.isGranted
        if !hasAccessibilityPermission {
            AccessibilityPermission.request()
            pollForPermission()
        }
        return hasAccessibilityPermission
    }

    /// The grant happens in System Settings while we run, so poll until it shows up.
    private func pollForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.hasAccessibilityPermission = AccessibilityPermission.isGranted
                if self.hasAccessibilityPermission {
                    timer.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add the Settings row and update the footnote**

In `Sources/AudraApp/SettingsView.swift`, in `GeneralSettingsView.body`, add after the `Toggle("Detect the language …")` line:

```swift

            NaturalVoicesRow(model: model, store: model.modelStore)
```

Add this view at the end of the file:

```swift
/// Status of the natural voice model with Download / Retry / Remove.
private struct NaturalVoicesRow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: KokoroModelStore

    var body: some View {
        LabeledContent("Natural voices:") {
            HStack {
                Text(store.state.statusText(totalBytes: store.totalBytes))
                    .foregroundStyle(.secondary)
                switch store.state {
                case .notDownloaded:
                    Button("Download") { store.download() }
                case .failed:
                    Button("Retry") { store.download() }
                case .ready:
                    Button("Remove") { model.removeNaturalVoices() }
                case .downloading:
                    ProgressView().controlSize(.small)
                }
            }
        }
        .help(helpText)
    }

    private var helpText: String {
        if case let .failed(message) = store.state { return message }
        return "Natural-sounding voices for English, Portuguese, Spanish, French, Italian, Hindi, Japanese and Chinese, running on this Mac."
    }
}
```

In `VoiceSettingsView`, replace the footnote text with:

```swift
                Text("Used when text in that language is detected. Natural voices are preferred once downloaded (Settings → General). Download more system voices in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices.")
```

- [ ] **Step 3: Show download progress in the menu**

In `Sources/AudraApp/MenuBarContent.swift`, add a property to `MenuBarContent` after `@ObservedObject var settings: SettingsStore`:

```swift
    @ObservedObject var modelStore: KokoroModelStore
```

and insert at the top of `body`, before `if !model.hasAccessibilityPermission {`:

```swift
        if case let .downloading(progress) = modelStore.state {
            Text("Downloading natural voices… \(Int((progress * 100).rounded(.down)))%")
            Divider()
        }
```

In `Sources/AudraApp/AudraApp.swift`, change the menu content line to:

```swift
            MenuBarContent(model: model, speech: model.speech, settings: model.settings, modelStore: model.modelStore)
```

- [ ] **Step 4: Build and test**

Run: `./scripts/build-app.sh && make test 2>&1 | tail -3`
Expected: `Built build/Audra.app`; tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraApp
git commit -m "feat: use natural Kokoro voices in the app

Downloads the model on first launch, lists natural voices in the pickers once
ready, and shows status with Download/Retry/Remove in Settings.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Docs and licensing

**Files:**
- Create: `LICENSE`, `THIRD_PARTY_NOTICES.md`
- Modify: `README.md`, `docs/superpowers/specs/2026-10-01-audra-design.md`

- [ ] **Step 1: License**

```bash
cp Packages/ESpeakNG/LICENSE LICENSE
head -2 LICENSE
```

Expected: `GNU GENERAL PUBLIC LICENSE` / `Version 3, 29 June 2007`.

Create `THIRD_PARTY_NOTICES.md`:

```markdown
# Third-party notices

Audra is licensed under the GNU General Public License v3.0 (see LICENSE), because it
includes eSpeak NG. It also includes or downloads the following:

| Component | License | Source |
|---|---|---|
| eSpeak NG 1.52.0 (prebuilt framework, vendored in `Packages/ESpeakNG`) | GPL-3.0-or-later | https://github.com/espeak-ng/espeak-ng/tree/1.52.0, built by https://github.com/mlalma/eSpeakNGSwift (a2b2fbb) |
| KokoroSwift (vendored and patched in `Packages/KokoroSwift`) | MIT | https://github.com/mlalma/kokoro-ios (4d6d1d8) |
| MisakiSwift | MIT | https://github.com/mlalma/MisakiSwift |
| MLX Swift | MIT | https://github.com/ml-explore/mlx-swift |
| MLXUtilsLibrary | MIT | https://github.com/mlalma/MLXUtilsLibrary |
| KeyboardShortcuts | MIT | https://github.com/sindresorhus/KeyboardShortcuts |
| Kokoro-82M v1.0 model weights and voices (downloaded at runtime) | Apache-2.0 | https://huggingface.co/hexgrad/Kokoro-82M |
| misaki G2P tables and rules, ported in `Sources/AudraCore/Phonemes` | Apache-2.0 | https://github.com/hexgrad/misaki |
| cutlet kana table (via misaki) | MIT | https://github.com/polm/cutlet |
| pinyin-to-ipa transcription rules (via misaki) | MIT | https://github.com/stefantaubert/pinyin-to-ipa |
```

- [ ] **Step 2: README**

Apply these edits to `README.md`:

1. Line 3 becomes: `A small macOS menu bar app that reads aloud the text you select in any application, with natural-sounding voices that run on your Mac.`
2. Replace the bullet `- Uses the voices installed on your Mac. No internet connection needed.` with:

```markdown
- Natural neural voices (Kokoro) for English, Portuguese (Brazil), Spanish, French, Italian, Hindi, Japanese and Chinese (beta), generated on your Mac. Other languages use the voices installed on your Mac.
```

3. Replace `- Never stores or transmits the text it reads.` with:

```markdown
- Never stores or transmits the text it reads. The only network access is a one-time download of the natural voice model (about 190 MB) on first launch.
```

4. Replace the two Requirements bullets with:

```markdown
- macOS 15 Sequoia or later on Apple Silicon
- To build: Xcode 26 or later (Swift 6.2+) with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`)
```

5. In Install step 2, delete the line `   - **macOS 14:** right-click the app → **Open** → **Open**.` and change `   - **macOS 15 and later:** open the app once` to `   - Open the app once`.
6. Replace the paragraph starting `More voices (including Enhanced/Premium quality)` with:

```markdown
Natural voices download automatically the first time the app runs (progress shows in the menu bar menu and in Settings → General). Until then, and for languages they don't cover, the app uses the voices installed on your Mac — more of those (including Enhanced/Premium quality) can be downloaded in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices. To free the disk space, use **Remove** next to Natural voices in Settings → General.
```

7. In the Development block, replace the `swift test` and `./scripts/build-app.sh` lines with:

```bash
make test                  # run all tests (xcodebuild; ONLY=Target/TestClass for a subset)
swift test --filter AudraCoreTests   # fast: core logic only
./scripts/build-app.sh     # build "build/Audra.app" (Apple Silicon, ad-hoc signed)
```

8. In Project layout, add after the `AudraCore` bullet:

```markdown
- `Sources/AudraKokoro` — the Kokoro engine (MLX) and the English/eSpeak phonemizers.
- `Packages/` — vendored KokoroSwift (patched) and eSpeak NG; see their `VENDORED.md`.
- `scripts/prepare-kokoro-assets.py` — builds the model files published at https://github.com/buemura/audra-models/releases.
```

9. Replace the Tech Stack list with:

```markdown
- Swift, SwiftUI, AVFoundation, NaturalLanguage, Accessibility API
- [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) on [MLX Swift](https://github.com/ml-explore/mlx-swift) via [KokoroSwift](https://github.com/mlalma/kokoro-ios)
- [MisakiSwift](https://github.com/mlalma/MisakiSwift) and [eSpeak NG](https://github.com/espeak-ng/espeak-ng) for pronunciation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

## License

GPL-3.0 (see `LICENSE`). Third-party components are listed in `THIRD_PARTY_NOTICES.md`.
```

- [ ] **Step 3: Mark the superseded v1 decision**

In `docs/superpowers/specs/2026-10-01-audra-design.md`, append to the end of the `| Privacy |` table row's decision text (before the closing `|`): ` Superseded by 2026-10-01-natural-voices-design.md: the one-time model download is the only network access.` Do the same for the `| Platform |` row: ` Now macOS 15+, Apple Silicon only (natural voices design).`

- [ ] **Step 4: Commit**

```bash
git add LICENSE THIRD_PARTY_NOTICES.md README.md docs/superpowers/specs/2026-10-01-audra-design.md
git commit -m "docs: document natural voices, license under GPL-3.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Manual verification in the built app

No code changes. This step checks what unit tests can't: audio, the MLX runtime inside the app bundle, the real download, and the UI. Report each check as passed or failed, with details for any failure.

- [ ] **Step 1: Fresh install**

```bash
mv ~/Library/Application\ Support/Audra/Kokoro ~/Library/Application\ Support/Audra/Kokoro.bak 2>/dev/null || true
make run
```

Checks:
1. The menu bar menu shows `Downloading natural voices… N%`, increasing. When it finishes, Settings → General → Natural voices shows `Ready (190.x MB)` with **Remove**. (This needs Task 14's publish. If it was skipped, expect `Download failed`: check that **Retry** works after publishing.)
2. Settings → Voices lists natural voices, e.g. `Dora (pt-BR, Natural)` under Portuguese.

- [ ] **Step 2: Read in every Kokoro language**

Select each line in a text editor and press ⌥⇧S. Each must play in a natural voice. The floating player subtitle should show the natural voice name, e.g. `1x · Dora (pt-BR)`.

```
Screen readers turn written text into speech. This one runs entirely on your Mac.
Leitores de tela transformam texto escrito em fala. Este roda inteiramente no seu Mac.
Los lectores de pantalla convierten el texto escrito en voz. Este funciona completamente en tu Mac.
Les lecteurs d'écran transforment le texte écrit en parole. Celui-ci fonctionne entièrement sur votre Mac.
I lettori di schermo trasformano il testo scritto in voce. Questo funziona interamente sul tuo Mac.
स्क्रीन रीडर लिखे हुए पाठ को आवाज़ में बदलते हैं।
スクリーンリーダーは、書かれた文章を音声に変換します。今日は2026年10月1日です。
屏幕阅读器把文字变成语音。今天是二零二六年十月一日。
```

Also select some German (`Bildschirmleser verwandeln Text in Sprache.`) and confirm it uses a system voice.

- [ ] **Step 3: Controls**

With a long English paragraph (5+ sentences):
1. **Pause / Resume** from the player: playback stops and continues mid-sentence.
2. Press **▶▶** mid-reading: speech restarts from the start of the current sentence, faster.
3. Change the English voice in Settings → Voices mid-reading: it restarts from the current sentence in the new voice.
4. **Stop** halts at once; the hotkey starts a new reading.

- [ ] **Step 4: Remove and fallback**

1. Settings → General → **Remove**. Reading English now uses a system voice, and natural voices disappear from the pickers.
2. Quit, turn off Wi-Fi, and run `make open`. The status shows `Download failed`; hover it to see the error. Reading still works with system voices.
3. Turn Wi-Fi back on and click **Retry**. The model downloads and natural voices return.
4. Restore the backup if one was made: `rm -rf ~/Library/Application\ Support/Audra/Kokoro.bak`. The fresh download replaces it.

- [ ] **Step 5: Memory**

After a Kokoro reading, Activity Monitor shows Audra using roughly 0.5–1 GB. After 10 minutes without Kokoro speech, it drops back down, because the model is unloaded.
