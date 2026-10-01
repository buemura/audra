import ScreenReaderCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var speech: SpeechController

    var body: some View {
        Image(systemName: speech.state == .idle ? "speaker.wave.2" : "speaker.wave.2.fill")
    }
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechController
    @ObservedObject var settings: SettingsStore

    var body: some View {
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

        Divider()

        Button("Quit Screen Reader") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
