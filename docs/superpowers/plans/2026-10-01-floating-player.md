# Floating Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small always-on-top player widget (play/pause, slower, faster, stop, text snippet, speed and voice) that controls reading without the hotkey or menu bar.

**Architecture:** All button logic, labels and visibility rules live in a new `PlayerViewModel` in `AudraCore`, built on the existing `SpeechController` and `SettingsStore`, and unit-tested with the existing `FakeSynthesizer`. The app target adds a thin SwiftUI `PlayerView` and a `PlayerPanelController` that owns a non-activating, floating `NSPanel`. Non-activating matters: clicking the panel must not make Audra the frontmost app, or "read current selection" would read our own window. Speed changes reuse the existing `settings.$speed` → `SpeechController.changeRate` subscription in `ReadSelectionCoordinator`.

**Tech Stack:** Swift (tools 5.10, Swift 5 language mode), SwiftUI, AppKit (`NSPanel`, `NSHostingView`), Combine, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-01-floating-player-design.md`

## Global Constraints

- Minimum macOS: **14.0**. Do not use APIs newer than macOS 14 (e.g. no `WindowDragGesture`, no `.glassEffect`, no `.windowLevel`).
- `// swift-tools-version: 5.10` stays. No new dependencies.
- `AudraCore` must not import AppKit or SwiftUI.
- Look: solid grey card that adapts to light/dark. **No glass or blur.** ~240×120 pt, corner radius 20 pt.
- Hide delay after reading goes idle: **3 s**. Fade duration: **~0.2 s**.
- Placeholder title: exactly `Select text and press play`. Voice fallback label: exactly `System voice`. Subtitle separator: ` · ` (space, U+00B7, space).
- Settings key for the new toggle: `alwaysShowPlayer`, default `false`. Menu item label: `Show Player Always`.
- Privacy: the text being read is kept in memory only. Never persist, log or `print` it.
- Tests use **XCTest** and run with `swift test`. Every command runs from the repo root: `/Users/buemura/dev/projects/screen-reader`.
- Every commit message ends with the trailer line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (after a blank line).

## File Structure

```
Sources/AudraCore/Speech/SpeechSpeed.swift          # + slower / faster (Task 1)
Sources/AudraCore/Speech/SpeechController.swift     # + currentText / currentVoiceID (Task 2)
Sources/AudraCore/Settings/SettingsStore.swift      # + alwaysShowPlayer (Task 3)
Sources/AudraCore/Player/PlayerViewModel.swift      # NEW: player logic, labels, visibility (Task 4)
Sources/AudraApp/Player/PlayerView.swift            # NEW: SwiftUI layout of the widget (Task 5)
Sources/AudraApp/Player/PlayerPanelController.swift # NEW: NSPanel, show/hide, position (Task 5)
Sources/AudraApp/AppModel.swift                     # creates view model + panel (Task 5)
Sources/AudraApp/MenuBarContent.swift               # + "Show Player Always" toggle (Task 6)
README.md                                                  # document the player (Task 6)
Tests/AudraCoreTests/SpeechSpeedTests.swift         # (Task 1)
Tests/AudraCoreTests/SpeechControllerTests.swift    # (Task 2)
Tests/AudraCoreTests/SettingsStoreTests.swift       # (Task 3)
Tests/AudraCoreTests/PlayerViewModelTests.swift     # NEW (Task 4)
```

---

### Task 1: Speed stepping on `SpeechSpeed`

**Files:**
- Modify: `Sources/AudraCore/Speech/SpeechSpeed.swift`
- Test: `Tests/AudraCoreTests/SpeechSpeedTests.swift`

**Interfaces:**
- Consumes: existing `SpeechSpeed` enum (`allCases` order: `.half, .normal, .oneAndHalf, .double, .twoAndHalf`).
- Produces: `public var slower: SpeechSpeed? { get }` and `public var faster: SpeechSpeed? { get }`. They return the adjacent case in `allCases`, or `nil` at the ends.

- [ ] **Step 1: Write the failing tests**

Add these methods inside `SpeechSpeedTests` in `Tests/AudraCoreTests/SpeechSpeedTests.swift`:

```swift
    func testFasterStepsToNextSpeedAndStopsAtTheTop() {
        XCTAssertEqual(SpeechSpeed.half.faster, .normal)
        XCTAssertEqual(SpeechSpeed.normal.faster, .oneAndHalf)
        XCTAssertEqual(SpeechSpeed.double.faster, .twoAndHalf)
        XCTAssertNil(SpeechSpeed.twoAndHalf.faster)
    }

    func testSlowerStepsToPreviousSpeedAndStopsAtTheBottom() {
        XCTAssertEqual(SpeechSpeed.twoAndHalf.slower, .double)
        XCTAssertEqual(SpeechSpeed.normal.slower, .half)
        XCTAssertNil(SpeechSpeed.half.slower)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SpeechSpeedTests`
Expected: build failure, `value of type 'SpeechSpeed' has no member 'faster'` (and `slower`).

- [ ] **Step 3: Implement**

In `Sources/AudraCore/Speech/SpeechSpeed.swift`, add inside the enum, after `label`:

```swift
    /// The next slower speed, or nil at the slowest.
    public var slower: SpeechSpeed? { neighbor(offset: -1) }

    /// The next faster speed, or nil at the fastest.
    public var faster: SpeechSpeed? { neighbor(offset: 1) }

    private func neighbor(offset: Int) -> SpeechSpeed? {
        let all = Self.allCases
        let index = all.firstIndex(of: self)! + offset
        return all.indices.contains(index) ? all[index] : nil
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SpeechSpeedTests`
Expected: all `SpeechSpeedTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Speech/SpeechSpeed.swift Tests/AudraCoreTests/SpeechSpeedTests.swift
git commit -m "feat: add slower/faster speed stepping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Expose what is being read on `SpeechController`

**Files:**
- Modify: `Sources/AudraCore/Speech/SpeechController.swift`
- Test: `Tests/AudraCoreTests/SpeechControllerTests.swift`

**Interfaces:**
- Consumes: existing `SpeechController.speak(_:voiceID:rate:)`, `changeRate(_:)`, `stop()`, and `FakeSynthesizer` (`Tests/AudraCoreTests/Fakes/FakeSynthesizer.swift`, with `finish()` and `progress(to:)`).
- Produces: `@Published public private(set) var currentText: String?` and `@Published public private(set) var currentVoiceID: String?`. `speak` sets them to the original text and voice. `changeRate`, `stop` and a natural finish do **not** change them. Both are `nil` before the first `speak`.

- [ ] **Step 1: Write the failing tests**

Add inside `SpeechControllerTests`:

```swift
    func testCurrentTextAndVoiceAreNilBeforeSpeaking() {
        makeController()
        XCTAssertNil(controller.currentText)
        XCTAssertNil(controller.currentVoiceID)
    }

    func testSpeakRecordsCurrentTextAndVoice() {
        makeController()
        controller.speak("Hello", voiceID: "v1", rate: 0.5)
        XCTAssertEqual(controller.currentText, "Hello")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Bye", voiceID: nil, rate: 0.5)
        XCTAssertEqual(controller.currentText, "Bye")
        XCTAssertNil(controller.currentVoiceID)
    }

    func testCurrentTextKeepsOriginalTextAfterRateChangeStopAndFinish() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", rate: 0.5)
        synthesizer.progress(to: 6)
        controller.changeRate(0.7)
        XCTAssertEqual(controller.currentText, "Hello brave new world")

        controller.stop()
        XCTAssertEqual(controller.currentText, "Hello brave new world")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Again", voiceID: "v1", rate: 0.5)
        synthesizer.finish()
        XCTAssertEqual(controller.currentText, "Again")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SpeechControllerTests`
Expected: build failure, `value of type 'SpeechController' has no member 'currentText'`.

- [ ] **Step 3: Implement**

In `Sources/AudraCore/Speech/SpeechController.swift`, add below `@Published public private(set) var state: State = .idle`:

```swift
    /// The text of the current (or last) reading, as originally given to `speak`.
    /// Kept in memory only; never persisted.
    @Published public private(set) var currentText: String?
    /// The voice of the current (or last) reading. nil = system default.
    @Published public private(set) var currentVoiceID: String?
```

In `speak(_:voiceID:rate:)`, add these two lines directly after `if state != .idle { synthesizer.stop() }`:

```swift
        currentText = text
        currentVoiceID = voiceID
```

Do not touch `changeRate`. It keeps trimming the private `text` property, which is separate from `currentText`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SpeechControllerTests`
Expected: all `SpeechControllerTests` pass, old and new.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Speech/SpeechController.swift Tests/AudraCoreTests/SpeechControllerTests.swift
git commit -m "feat: publish current text and voice from SpeechController

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `alwaysShowPlayer` setting

**Files:**
- Modify: `Sources/AudraCore/Settings/SettingsStore.swift`
- Test: `Tests/AudraCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: existing `SettingsStore(defaults:)` pattern (`Key` enum, `didSet` persistence).
- Produces: `@Published public var alwaysShowPlayer: Bool`. UserDefaults key `alwaysShowPlayer`, default `false`.

- [ ] **Step 1: Write the failing tests**

Add inside `SettingsStoreTests`:

```swift
    func testAlwaysShowPlayerDefaultsToFalse() {
        XCTAssertFalse(SettingsStore(defaults: makeDefaults()).alwaysShowPlayer)
    }

    func testAlwaysShowPlayerPersists() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).alwaysShowPlayer = true
        XCTAssertTrue(SettingsStore(defaults: defaults).alwaysShowPlayer)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter SettingsStoreTests`
Expected: build failure, `value of type 'SettingsStore' has no member 'alwaysShowPlayer'`.

- [ ] **Step 3: Implement**

In `Sources/AudraCore/Settings/SettingsStore.swift`:

Add to `enum Key`:

```swift
        static let alwaysShowPlayer = "alwaysShowPlayer"
```

Add after the `autoDetectLanguage` property:

```swift
    /// Keep the floating player visible while idle, not only while reading.
    @Published public var alwaysShowPlayer: Bool {
        didSet { defaults.set(alwaysShowPlayer, forKey: Key.alwaysShowPlayer) }
    }
```

Add to `init`, after the `autoDetectLanguage` line:

```swift
        alwaysShowPlayer = defaults.bool(forKey: Key.alwaysShowPlayer)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter SettingsStoreTests`
Expected: all `SettingsStoreTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Settings/SettingsStore.swift Tests/AudraCoreTests/SettingsStoreTests.swift
git commit -m "feat: add alwaysShowPlayer setting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `PlayerViewModel`

**Files:**
- Create: `Sources/AudraCore/Player/PlayerViewModel.swift`
- Test: `Tests/AudraCoreTests/PlayerViewModelTests.swift`

**Interfaces:**
- Consumes:
  - `SpeechController`: `state: State` (`.idle/.speaking/.paused`), `currentText: String?`, `currentVoiceID: String?`, `pause()`, `resume()`, `stop()`, `speak(_:voiceID:rate:)`. `objectWillChange` and `$state` are its publishers.
  - `SettingsStore`: `speed: SpeechSpeed`, `alwaysShowPlayer: Bool`, `$alwaysShowPlayer`, `objectWillChange`.
  - `SpeechSpeed.slower`, `.faster`, `.label` (Task 1).
  - `VoiceInfo` (`id`, `name`, `language`).
- Produces (used by Task 5):

```swift
@MainActor public final class PlayerViewModel: ObservableObject {
    public init(
        speech: SpeechController,
        settings: SettingsStore,
        availableVoices: @escaping () -> [VoiceInfo],
        readSelection: @escaping @MainActor () async -> Void
    )
    @Published public private(set) var shouldBeVisible: Bool   // state != .idle || settings.alwaysShowPlayer
    public var isPlaying: Bool { get }      // state == .speaking
    public var canStop: Bool { get }        // state != .idle
    public var canGoSlower: Bool { get }
    public var canGoFaster: Bool { get }
    public var title: String { get }
    public var subtitle: String { get }
    public func playPause() async
    public func slower()
    public func faster()
    public func stop()
}
```

`shouldBeVisible` is a stored `@Published` property (not computed) so that `PlayerPanelController` can subscribe to `$shouldBeVisible` and receive the **new** value. A sink on `objectWillChange` would read the old value. The other properties are computed, and `objectWillChange` is forwarded from `speech` and `settings` so SwiftUI re-renders.

- [ ] **Step 1: Write the failing tests**

Create `Tests/AudraCoreTests/PlayerViewModelTests.swift`:

```swift
import Combine
import XCTest
@testable import AudraCore

@MainActor
final class PlayerViewModelTests: XCTestCase {
    private let portuguese = VoiceInfo(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard)

    private var synthesizer: FakeSynthesizer!
    private var speech: SpeechController!
    private var settings: SettingsStore!
    private var readSelectionCount = 0

    private func makeModel() -> PlayerViewModel {
        let suiteName = "AudraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        synthesizer = FakeSynthesizer()
        speech = SpeechController(synthesizer: synthesizer)
        settings = SettingsStore(defaults: defaults)
        readSelectionCount = 0
        let voices = [portuguese]
        return PlayerViewModel(
            speech: speech,
            settings: settings,
            availableVoices: { voices },
            readSelection: { [unowned self] in self.readSelectionCount += 1 }
        )
    }

    // MARK: Play / pause

    func testPlayPauseWhenIdleReadsSelection() async {
        let model = makeModel()
        await model.playPause()
        XCTAssertEqual(readSelectionCount, 1)
        XCTAssertEqual(synthesizer.calls, [])
    }

    func testPlayPauseWhileSpeakingPauses() async {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        await model.playPause()
        XCTAssertEqual(speech.state, .paused)
        XCTAssertEqual(readSelectionCount, 0)
    }

    func testPlayPauseWhilePausedResumes() async {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        speech.pause()
        await model.playPause()
        XCTAssertEqual(speech.state, .speaking)
        XCTAssertEqual(readSelectionCount, 0)
    }

    func testIsPlayingOnlyWhileSpeaking() {
        let model = makeModel()
        XCTAssertFalse(model.isPlaying)
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        XCTAssertTrue(model.isPlaying)
        speech.pause()
        XCTAssertFalse(model.isPlaying)
    }

    // MARK: Stop

    func testStopStopsSpeechAndIsOnlyEnabledWhileNotIdle() {
        let model = makeModel()
        XCTAssertFalse(model.canStop)
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        XCTAssertTrue(model.canStop)
        speech.pause()
        XCTAssertTrue(model.canStop)

        model.stop()
        XCTAssertEqual(speech.state, .idle)
        XCTAssertFalse(model.canStop)
    }

    // MARK: Speed

    func testSlowerAndFasterStepTheSpeedSetting() {
        let model = makeModel()
        settings.speed = .normal
        model.faster()
        XCTAssertEqual(settings.speed, .oneAndHalf)
        model.slower()
        model.slower()
        XCTAssertEqual(settings.speed, .half)
    }

    func testSpeedButtonsAreDisabledAndNoOpsAtTheEnds() {
        let model = makeModel()
        settings.speed = .half
        XCTAssertFalse(model.canGoSlower)
        XCTAssertTrue(model.canGoFaster)
        model.slower()
        XCTAssertEqual(settings.speed, .half)

        settings.speed = .twoAndHalf
        XCTAssertTrue(model.canGoSlower)
        XCTAssertFalse(model.canGoFaster)
        model.faster()
        XCTAssertEqual(settings.speed, .twoAndHalf)
    }

    // MARK: Labels

    func testTitleIsPlaceholderBeforeAnyReading() {
        let model = makeModel()
        XCTAssertEqual(model.title, "Select text and press play")
    }

    func testTitleCollapsesWhitespace() {
        let model = makeModel()
        speech.speak("  Hello\n\n  brave\tworld  ", voiceID: nil, rate: 0.5)
        XCTAssertEqual(model.title, "Hello brave world")
    }

    func testTitleKeepsLastTextAfterStop() {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        speech.stop()
        XCTAssertEqual(model.title, "Hello")
    }

    func testSubtitleIsSpeedOnlyBeforeAnyReading() {
        let model = makeModel()
        settings.speed = .oneAndHalf
        XCTAssertEqual(model.subtitle, "1.5x")
    }

    func testSubtitleShowsSpeedAndInstalledVoice() {
        let model = makeModel()
        settings.speed = .oneAndHalf
        speech.speak("Olá", voiceID: "pt.luciana", rate: 0.5)
        XCTAssertEqual(model.subtitle, "1.5x · Luciana (pt-BR)")
    }

    func testSubtitleFallsBackToSystemVoiceForNilOrUnknownVoice() {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        XCTAssertEqual(model.subtitle, "1x · System voice")
        speech.speak("Hello", voiceID: "not.installed", rate: 0.5)
        XCTAssertEqual(model.subtitle, "1x · System voice")
    }

    func testSubtitleFollowsSpeedChanges() {
        let model = makeModel()
        speech.speak("Olá", voiceID: "pt.luciana", rate: 0.5)
        model.faster()
        XCTAssertEqual(model.subtitle, "1.5x · Luciana (pt-BR)")
    }

    // MARK: Visibility

    func testShouldBeVisibleWhileSpeakingOrPausedOnly() {
        let model = makeModel()
        XCTAssertFalse(model.shouldBeVisible)
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        XCTAssertTrue(model.shouldBeVisible)
        speech.pause()
        XCTAssertTrue(model.shouldBeVisible)
        speech.stop()
        XCTAssertFalse(model.shouldBeVisible)
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        synthesizer.finish()
        XCTAssertFalse(model.shouldBeVisible)
    }

    func testShouldBeVisibleWhileIdleWhenAlwaysShowPlayerIsOn() {
        let model = makeModel()
        settings.alwaysShowPlayer = true
        XCTAssertTrue(model.shouldBeVisible)
        settings.alwaysShowPlayer = false
        XCTAssertFalse(model.shouldBeVisible)
    }

    func testShouldBeVisiblePublisherDeliversNewValues() {
        let model = makeModel()
        var received: [Bool] = []
        let subscription = model.$shouldBeVisible.sink { received.append($0) }
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        speech.pause()
        speech.stop()
        subscription.cancel()
        XCTAssertEqual(received, [false, true, false])
    }

    // MARK: Change notifications

    func testForwardsChangesFromSpeechAndSettings() {
        let model = makeModel()
        var changes = 0
        let subscription = model.objectWillChange.sink { changes += 1 }
        speech.speak("Hello", voiceID: nil, rate: 0.5)
        let afterSpeak = changes
        XCTAssertGreaterThan(afterSpeak, 0)
        settings.speed = .double
        XCTAssertGreaterThan(changes, afterSpeak)
        subscription.cancel()
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter PlayerViewModelTests`
Expected: build failure, `cannot find 'PlayerViewModel' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/AudraCore/Player/PlayerViewModel.swift`:

```swift
import Combine
import Foundation

/// State and actions behind the floating player widget.
@MainActor
public final class PlayerViewModel: ObservableObject {
    /// Whether the player should be on screen. Stored (not computed) so `$shouldBeVisible`
    /// delivers new values; hide delays and animation are the window's job.
    @Published public private(set) var shouldBeVisible = false

    private let speech: SpeechController
    private let settings: SettingsStore
    private let availableVoices: () -> [VoiceInfo]
    private let readSelection: @MainActor () async -> Void
    private var changeSubscription: AnyCancellable?

    public init(
        speech: SpeechController,
        settings: SettingsStore,
        availableVoices: @escaping () -> [VoiceInfo],
        readSelection: @escaping @MainActor () async -> Void
    ) {
        self.speech = speech
        self.settings = settings
        self.availableVoices = availableVoices
        self.readSelection = readSelection

        Publishers.CombineLatest(speech.$state, settings.$alwaysShowPlayer)
            .map { state, alwaysShow in state != .idle || alwaysShow }
            .removeDuplicates()
            .assign(to: &$shouldBeVisible)

        // Labels and button states are derived from these two objects, so re-render with them.
        changeSubscription = speech.objectWillChange
            .merge(with: settings.objectWillChange)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    public var isPlaying: Bool { speech.state == .speaking }
    public var canStop: Bool { speech.state != .idle }
    public var canGoSlower: Bool { settings.speed.slower != nil }
    public var canGoFaster: Bool { settings.speed.faster != nil }

    /// The text being read (or last read), on one line.
    public var title: String {
        guard let text = speech.currentText else { return "Select text and press play" }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// "1.5x · Luciana (pt-BR)", or just the speed before anything was read.
    public var subtitle: String {
        let speed = settings.speed.label
        guard speech.currentText != nil else { return speed }
        let voice = speech.currentVoiceID.flatMap { id in availableVoices().first { $0.id == id } }
        let voiceLabel = voice.map { "\($0.name) (\($0.language))" } ?? "System voice"
        return "\(speed) · \(voiceLabel)"
    }

    /// Idle: read the current selection. Speaking: pause. Paused: resume.
    public func playPause() async {
        switch speech.state {
        case .idle: await readSelection()
        case .speaking: speech.pause()
        case .paused: speech.resume()
        }
    }

    public func slower() {
        if let speed = settings.speed.slower { settings.speed = speed }
    }

    public func faster() {
        if let speed = settings.speed.faster { settings.speed = speed }
    }

    public func stop() {
        speech.stop()
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter PlayerViewModelTests`
Expected: all `PlayerViewModelTests` pass.

Then run the full suite to make sure nothing else broke: `swift test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AudraCore/Player/PlayerViewModel.swift Tests/AudraCoreTests/PlayerViewModelTests.swift
git commit -m "feat: add PlayerViewModel for the floating player

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Floating panel and player view

The AppKit window and SwiftUI layout can't be unit-tested here. This task is verified by building and running the app (Step 5).

**Files:**
- Create: `Sources/AudraApp/Player/PlayerView.swift`
- Create: `Sources/AudraApp/Player/PlayerPanelController.swift`
- Modify: `Sources/AudraApp/AppModel.swift`

**Interfaces:**
- Consumes: `PlayerViewModel` (Task 4): `init(speech:settings:availableVoices:readSelection:)`, `$shouldBeVisible`, `isPlaying`, `canStop`, `canGoSlower`, `canGoFaster`, `title`, `subtitle`, `playPause() async`, `slower()`, `faster()`, `stop()`. Also `SystemVoices.all() -> [VoiceInfo]` and `AppModel.readSelection() async`.
- Produces: `PlayerView(model: PlayerViewModel)`, `PlayerPanelController(viewModel: PlayerViewModel)`. `AppModel` keeps the controller alive in `private var playerPanel: PlayerPanelController?`.

- [ ] **Step 1: Create the SwiftUI view**

Create `Sources/AudraApp/Player/PlayerView.swift`:

```swift
import AppKit
import AudraCore
import SwiftUI

/// The floating player: what's being read on top, playback controls below.
struct PlayerView: View {
    static let size = CGSize(width: 240, height: 120)

    @ObservedObject var model: PlayerViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(model.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                PlayerButton(symbol: "stop.fill", size: 11, help: "Stop") { model.stop() }
                    .disabled(!model.canStop)
            }

            HStack(spacing: 24) {
                PlayerButton(symbol: "backward.fill", size: 18, help: "Slower") { model.slower() }
                    .disabled(!model.canGoSlower)
                PlayerButton(
                    symbol: model.isPlaying ? "pause.fill" : "play.fill",
                    size: 26,
                    help: model.isPlaying ? "Pause" : "Play"
                ) {
                    Task { await model.playPause() }
                }
                PlayerButton(symbol: "forward.fill", size: 18, help: "Faster") { model.faster() }
                    .disabled(!model.canGoFaster)
            }
        }
        .padding(14)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(WindowDragArea())
        .background(Color(nsColor: .windowBackgroundColor), in: Self.card)
        .overlay(Self.card.strokeBorder(Color(nsColor: .separatorColor)))
        .clipShape(Self.card)
    }

    private static let card = RoundedRectangle(cornerRadius: 20, style: .continuous)
}

private struct PlayerButton: View {
    let symbol: String
    let size: CGFloat
    let help: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Lets the user drag the borderless panel by any spot that isn't a button.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
```

- [ ] **Step 2: Create the panel controller**

Create `Sources/AudraApp/Player/PlayerPanelController.swift`:

```swift
import AppKit
import Combine
import AudraCore
import SwiftUI

/// Owns the floating player window: an always-on-top panel that never activates the app,
/// so clicking it leaves the other app (and its text selection) frontmost.
@MainActor
final class PlayerPanelController {
    private static let autosaveName = "PlayerPanel"
    private static let hideDelay: Duration = .seconds(3)
    private static let fadeDuration: TimeInterval = 0.2
    private static let screenInset: CGFloat = 24

    private let panel: NSPanel
    private var visibilitySubscription: AnyCancellable?
    private var hideTask: Task<Void, Never>?
    /// False once a fade-out starts, so a fade-out finishing after a new show() doesn't hide the panel.
    private var isShown = false

    init(viewModel: PlayerViewModel) {
        // Borderless panels can't become key, so clicks never pull focus from the other app.
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PlayerView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = FirstMouseHostingView(rootView: PlayerView(model: viewModel))

        if !panel.setFrameUsingName(Self.autosaveName) {
            placeAtBottomRight()
        }
        panel.setFrameAutosaveName(Self.autosaveName)

        visibilitySubscription = viewModel.$shouldBeVisible.sink { [weak self] visible in
            if visible { self?.show() } else { self?.scheduleHide() }
        }
    }

    private func placeAtBottomRight() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - PlayerView.size.width - Self.screenInset,
            y: visible.minY + Self.screenInset
        ))
    }

    private func show() {
        hideTask?.cancel()
        hideTask = nil
        guard !isShown else { return }
        isShown = true
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        guard isShown else { return }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hideDelay)
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        isShown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
            }
        })
    }
}

/// Makes the first click on an inactive panel press the button instead of only focusing the window.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
```

- [ ] **Step 3: Wire it into `AppModel`**

In `Sources/AudraApp/AppModel.swift`:

Add a stored property below `private var permissionTimer: Timer?`:

```swift
    private var playerPanel: PlayerPanelController?
```

At the very end of `init()`, after the `if !hasAccessibilityPermission { ... }` block, add:

```swift
        let player = PlayerViewModel(
            speech: speech,
            settings: settings,
            availableVoices: { SystemVoices.all() },
            readSelection: { [weak self] in await self?.readSelection() }
        )
        playerPanel = PlayerPanelController(viewModel: player)
```

- [ ] **Step 4: Build and run the tests**

Run: `swift build && swift test`
Expected: the build succeeds with no new warnings in `Player/`, and all tests pass.

- [ ] **Step 5: Smoke-test the app**

Run:
```bash
./scripts/build-app.sh && tccutil reset Accessibility com.buemura.Audra; open "build/Audra.app"
```
Grant Accessibility when prompted. Then:
1. Select text in TextEdit and press ⌥⇧S. The player fades in at the bottom-right with the text snippet and `1x · <voice>`. Speech starts.
2. Press ⌥⇧S again. Speech stops, and the player fades out about 3 s later.
3. Start reading again. Click ❚❚ to pause, then ▶ to resume. Click ▶▶ twice: speech gets faster mid-sentence and the subtitle shows `2x`. Click ◀◀. Click ■: speech stops.
4. While the player is still visible after stopping, select text in Safari and click ▶ on the panel. The selection is read and Safari stays frontmost (its menu bar is still showing).
5. Drag the panel by an empty area, quit (menu bar → Quit) and relaunch. Start a reading: the panel shows up where you left it.

If any step fails, stop and debug with superpowers:systematic-debugging before committing.

- [ ] **Step 6: Commit**

```bash
git add Sources/AudraApp/Player Sources/AudraApp/AppModel.swift
git commit -m "feat: add floating player panel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: "Show Player Always" menu toggle, docs and full manual check

**Files:**
- Modify: `Sources/AudraApp/MenuBarContent.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `SettingsStore.alwaysShowPlayer` (Task 3); the panel from Task 5 already reacts to it through `PlayerViewModel.shouldBeVisible`.
- Produces: nothing new for other tasks.

- [ ] **Step 1: Add the menu toggle**

In `Sources/AudraApp/MenuBarContent.swift`, directly after the closing `}` of the `Picker("Speed", ...)` block and before the next `Divider()`, add:

```swift

        Toggle("Show Player Always", isOn: $settings.alwaysShowPlayer)
```

- [ ] **Step 2: Document the player in the README**

In `README.md`, in the `## Features` list, add after the `- Menu bar controls: ...` line:

```markdown
- Floating player that stays on top of other apps while reading: play/pause, slower, faster and stop. It hides itself a few seconds after reading stops; turn on **Show Player Always** in the menu bar to keep it visible. Drag it anywhere — it remembers its position.
```

In `## Usage`, append this paragraph after the first one (the one that ends `→ **Settings…**.`):

```markdown
You can also control reading from the floating player: ▶ reads the current selection (or pauses/resumes), ◀◀ / ▶▶ change the speed, ■ stops.
```

- [ ] **Step 3: Build, test, run the full manual check**

Run:
```bash
swift test && ./scripts/build-app.sh && tccutil reset Accessibility com.buemura.Audra; open "build/Audra.app"
```
Expected: all tests pass and the app launches. Grant Accessibility, then go through every check in the spec (`docs/superpowers/specs/2026-10-01-floating-player-design.md` → Testing → Manual checks):

1. The panel appears on a hotkey read and hides about 3 s after stop. With menu bar → **Show Player Always** on, it appears right away and stays while idle. Turning it off hides it about 3 s later.
2. It stays above other apps and on every Space. Put Safari in full screen and start a reading there: the panel shows over it.
3. Select text in Safari and in Chrome, then click ▶ on the panel. The selection is read and the source app stays frontmost.
4. The first click on any panel button works immediately, with no extra click needed to focus the panel.
5. ◀◀/▶▶ change the speed audibly mid-sentence, are greyed out at 0.5x and 2.5x, and the subtitle updates.
6. The dragged position survives a relaunch.
7. Switch System Settings → Appearance between Light and Dark. The card stays grey and the text stays readable in both.

Record any failure and fix it (superpowers:systematic-debugging) before committing.

- [ ] **Step 4: Commit**

```bash
git add Sources/AudraApp/MenuBarContent.swift README.md
git commit -m "feat: add Show Player Always toggle and document the player

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
