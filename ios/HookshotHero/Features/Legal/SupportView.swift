import SwiftUI

struct SupportView: View {
  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Support").appTextStyle(.h1).accessibilityAddTraits(.isHeader)
          supportSection(
            "Troubleshooting",
            body:
              "If the game is not responding as expected, return to the main menu and try again. If that does not help, close and reopen the app. Restarting your device can resolve persistent audio, display, or input problems."
          )
          supportSection(
            "Reporting an issue",
            body:
              "When reporting a problem, include the app version below, your iPhone model and iOS version, what you expected, what happened, and the steps that reproduce it. A verified public support destination has not yet been configured; check this screen after an app update for the official contact option."
          )
          VStack(alignment: .leading, spacing: 8) {
            Text("App information").appTextStyle(.h2).accessibilityAddTraits(.isHeader)
            Text("Hookshot Hero").appTextStyle(.paragraph)
            Text(AppVersionInformation.displayText()).appTextStyle(.paragraph)
              .accessibilityIdentifier("appVersionInformation")
          }
          .padding(16).appSurface()

          if let supportURL = LegalSupportLinks.supportURL {
            Link("Contact Support", destination: supportURL)
              .buttonStyle(AppPrimaryButtonStyle())
              .accessibilityIdentifier("externalSupportLink")
          }
        }
        .padding(24)
      }
    }
    .navigationTitle("Support")
    .appNavigationStyle()
    .accessibilityIdentifier("supportScreen")
  }

  private func supportSection(_ title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).appTextStyle(.h2).accessibilityAddTraits(.isHeader)
      Text(body).appTextStyle(.paragraph)
    }
    .padding(16).appSurface()
  }
}
