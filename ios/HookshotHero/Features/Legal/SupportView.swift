import SwiftUI

struct SupportView: View {
  var body: some View {
    AppSecondaryScreen(title: "Support") {
      supportSection(
        "Troubleshooting",
        body:
          "If the game is not responding as expected, return to the main menu and try again. If that does not help, close and reopen the app. Restarting your device can resolve persistent audio, display, or input problems."
      )
      supportSection(
        "Reporting an issue",
        body:
          "When reporting a problem, include the app version below, your iPhone model and iOS version, what you expected, what happened, and the steps that reproduce it. "
            + LegalSupportLinks.supportAvailabilityDescription
      )
      AppInformationSection(title: "App information") {
        Text("Hookshot Hero").appTextStyle(.paragraph)
        Text(AppVersionInformation.displayText()).appTextStyle(.caption)
          .foregroundStyle(AppTheme.Colors.textSecondary)
          .accessibilityIdentifier("appVersionInformation")
      }

      if let supportURL = LegalSupportLinks.supportURL {
        Link(destination: supportURL) {
          Label { Text("Contact Support") } icon: {
            Image(systemName: "arrow.up.right").accessibilityHidden(true)
          }
        }
          .buttonStyle(AppPrimaryButtonStyle())
          .accessibilityIdentifier("externalSupportLink")
      }
    }
    .accessibilityIdentifier("supportScreen")
  }

  private func supportSection(_ title: String, body: String) -> some View {
    AppInformationSection(title: title) {
      Text(body).appTextStyle(.paragraph)
    }
  }
}
