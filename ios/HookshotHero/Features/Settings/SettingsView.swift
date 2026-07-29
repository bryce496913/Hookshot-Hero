import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let dismiss: () -> Void
    var body: some View {
        Form {
            Toggle("Reduced Motion", isOn: $store.settings.reducedMotion)
                .accessibilityIdentifier("reducedMotionToggle")
            Toggle("Control Hints", isOn: $store.settings.controlHintsEnabled)
                .accessibilityIdentifier("controlHintsToggle")
            Button("Done", action: dismiss).accessibilityIdentifier("settingsDoneButton")
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settingsScreen")
    }
}
