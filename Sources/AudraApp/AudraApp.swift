import SwiftUI

@main
struct AudraApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model, speech: model.speech, settings: model.settings, modelStore: model.modelStore)
        } label: {
            MenuBarLabel()
        }

        Settings {
            SettingsView(model: model, settings: model.settings)
        }
    }
}
