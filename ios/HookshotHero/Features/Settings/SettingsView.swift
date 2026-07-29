import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let dismiss: () -> Void
    var body: some View {
        Form {
            Toggle("Music", isOn: $store.settings.musicEnabled)
            Toggle("Sound Effects", isOn: $store.settings.soundEffectsEnabled)
            Toggle("Haptics", isOn: $store.settings.hapticsEnabled)
            Toggle("Reduced Motion", isOn: $store.settings.reducedMotion)
            Toggle("Control Hints", isOn: $store.settings.controlHintsEnabled)
            Button("Done", action: dismiss).accessibilityIdentifier("settingsDoneButton")
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settingsScreen")
    }
}
