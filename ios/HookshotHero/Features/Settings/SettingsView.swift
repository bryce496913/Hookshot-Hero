import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let dismiss: () -> Void
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .appTextStyle(.h1)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gameplay")
                        .appTextStyle(.h2)
                    Toggle(isOn: $store.settings.reducedMotion) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reduced Motion").appTextStyle(.h3)
                            Text("Keeps gameplay feedback visible with less travel-heavy animation.")
                                .appTextStyle(.paragraph)
                                .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                        }
                    }
                    .tint(AppTheme.Colors.accent)
                    .accessibilityIdentifier("reducedMotionToggle")
                    Toggle(isOn: $store.settings.controlHintsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Control Hints").appTextStyle(.h3)
                            Text("Shows concise movement and Grapple reminders during play.")
                                .appTextStyle(.paragraph)
                                .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                        }
                    }
                    .tint(AppTheme.Colors.accent)
                    .accessibilityIdentifier("controlHintsToggle")
                    Picker("Control Layout", selection: $store.settings.controlLayout) {
                        ForEach(ControlLayout.allCases, id: \.self) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Control Layout")
                    .accessibilityIdentifier("controlLayoutPicker")
                }
                .padding(16)
                .appSurface()
                Spacer()
                Button("Done", action: dismiss)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .accessibilityIdentifier("settingsDoneButton")
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .appNavigationStyle()
        .accessibilityIdentifier("settingsScreen")
    }
}
