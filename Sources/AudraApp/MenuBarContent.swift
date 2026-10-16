import AppKit
import AudraCore
import SwiftUI

struct MenuBarLabel: View {
    /// The Audra logo as a template image, so macOS tints it to match the menu bar.
    private static let icon: NSImage = {
        let image = Bundle.module.image(forResource: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        return image
    }()

    var body: some View {
        Image(nsImage: Self.icon)
    }
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechController
    @ObservedObject var settings: SettingsStore
    @ObservedObject var modelStore: KokoroModelStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if case let .downloading(progress) = modelStore.state {
            Text("Downloading natural voices… \(Int((progress * 100).rounded(.down)))%")
            Divider()
        }
        if !model.hasAccessibilityPermission {
            Button("⚠️ Grant Accessibility Access…") { AccessibilityPermission.openSystemSettings() }
            Divider()
        }

        Button("Read Selection") { Task { await model.readSelection() } }
        Button(speech.state == .paused ? "Resume" : "Pause") { speech.togglePause() }
            .disabled(speech.state == .idle)
        Button("Stop") { speech.stop() }
            .disabled(speech.state == .idle)

        Divider()

        Picker("Speed", selection: $settings.speed) {
            ForEach(SpeechSpeed.allCases) { speed in
                Text(speed.label).tag(speed)
            }
        }

        Toggle("Show Player Always", isOn: $settings.alwaysShowPlayer)

        Divider()

        Button("Settings…") {
            // Menu bar apps aren't active, so bring the window to the front explicitly.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit Audra") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
