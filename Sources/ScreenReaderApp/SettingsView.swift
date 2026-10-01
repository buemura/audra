import KeyboardShortcuts
import ScreenReaderCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(model: model, settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            VoiceSettingsView(model: model, settings: settings)
                .tabItem { Label("Voices", systemImage: "person.wave.2") }
        }
        .frame(width: 520, height: 440)
        .onAppear { model.refreshVoices() }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Read / stop selection:", name: .readSelection)

            Picker("Speed:", selection: $settings.speed) {
                ForEach(SpeechSpeed.allCases) { speed in
                    Text(speed.label).tag(speed)
                }
            }

            Picker("Default voice:", selection: $settings.defaultVoiceID) {
                Text("System default").tag(String?.none)
                ForEach(model.voices) { voice in
                    Text(voice.menuLabel).tag(Optional(voice.id))
                }
            }

            Toggle("Detect the language of the text and use a matching voice", isOn: $settings.autoDetectLanguage)
        }
        .formStyle(.grouped)
    }
}

private struct VoiceSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                ForEach(LanguageVoiceGroup.groups(from: model.voices)) { group in
                    Picker(group.displayName, selection: binding(for: group.languageCode)) {
                        Text("Automatic").tag(String?.none)
                        ForEach(group.voices) { voice in
                            Text(voice.menuLabel).tag(Optional(voice.id))
                        }
                    }
                }
            } footer: {
                Text("Used when text in that language is detected. Download more voices in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(!settings.autoDetectLanguage)
    }

    private func binding(for languageCode: String) -> Binding<String?> {
        Binding(
            get: { settings.languageVoiceOverrides[languageCode] },
            set: { settings.setVoiceOverride($0, forLanguage: languageCode) }
        )
    }
}
