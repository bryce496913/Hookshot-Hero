import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  let dismiss: () -> Void
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    AppSecondaryScreen(title: "Settings") {
      AppInformationSection(title: "Gameplay", systemImage: "hand.tap") {
        Toggle(isOn: $store.settings.reducedMotion) {
          AppSettingLabel(title: "Reduced Motion",
                          explanation: "Keeps gameplay feedback visible with less travel-heavy animation.")
        }
        .tint(AppTheme.Colors.accent)
        .accessibilityIdentifier("reducedMotionToggle")
        AppDivider()
        Toggle(isOn: $store.settings.controlHintsEnabled) {
          AppSettingLabel(title: "Control Hints",
                          explanation: "Shows concise movement and Grapple reminders during play.")
        }
        .tint(AppTheme.Colors.accent)
        .accessibilityIdentifier("controlHintsToggle")
        AppDivider()
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
          AppSettingLabel(title: "Control Layout", explanation: "Choose which side holds the joystick.")
          if dynamicTypeSize.isAccessibilitySize {
            layoutPicker.pickerStyle(.menu)
          } else {
            layoutPicker.pickerStyle(.segmented)
          }
        }
      }
      AppInformationSection(title: "Information", systemImage: "info.circle") {
        NavigationLink { SettingsHelpDestination() } label: {
          AppNavigationRow(title: "Help", systemImage: "questionmark.circle", subtitle: "Your dungeon guide")
        }
        .accessibilityLabel("Help").accessibilityIdentifier("settingsHelpLink")
        AppDivider()
        NavigationLink { PrivacyPolicyView() } label: {
          AppNavigationRow(title: "Privacy Policy", systemImage: "shield", subtitle: "How information is handled")
        }
        .accessibilityLabel("Privacy Policy").accessibilityIdentifier("privacyPolicyLink")
        AppDivider()
        NavigationLink { SupportView() } label: {
          AppNavigationRow(title: "Support", systemImage: "lifepreserver", subtitle: "Troubleshooting and contact")
        }
        .accessibilityLabel("Support").accessibilityIdentifier("supportLink")
        AppDivider()
        NavigationLink { CreditsLicensesView() } label: {
          AppNavigationRow(title: "Credits & Licenses", systemImage: "doc.text", subtitle: "Creators and legal information")
        }
        .accessibilityLabel("Credits & Licenses").accessibilityIdentifier("creditsLicensesLink")
      }
      AppInformationSection(title: "About") {
        Text("Hookshot Hero").appTextStyle(.h3)
        Text(AppVersionInformation.displayText()).appTextStyle(.caption)
          .foregroundStyle(AppTheme.Colors.textSecondary)
          .accessibilityIdentifier("settingsVersionInformation")
      }
      Button("Done", action: dismiss).buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("settingsDoneButton")
    }
    .accessibilityIdentifier("settingsScreen")
  }

  private var layoutPicker: some View {
    Picker("Control Layout", selection: $store.settings.controlLayout) {
      ForEach(ControlLayout.allCases, id: \.self) { layout in
        Text(layout.displayName).tag(layout)
      }
    }
    .tint(AppTheme.Colors.accent)
    .accessibilityLabel("Control Layout")
    .accessibilityIdentifier("controlLayoutPicker")
  }
}

/// Help's Done action pops this destination without dismissing Settings.
private struct SettingsHelpDestination: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View { HelpView(dismiss: { dismiss() }) }
}
