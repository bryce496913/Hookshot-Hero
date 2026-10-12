import SwiftUI

struct PrivacyPolicyView: View {
  var body: some View {
    AppSecondaryScreen(title: "Privacy Policy") {
      Text("Effective \(PrivacyPolicyContent.effectiveDate)")
        .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.accent)
        .padding(.horizontal, AppTheme.Spacing.sm).padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.surfaceElevated, in: Capsule())
      AppCard {
        Text(PrivacyPolicyContent.introduction).appTextStyle(.paragraph)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      ForEach(PrivacyPolicyContent.sections) { section in
        AppInformationSection(title: section.title) {
          Text(section.body).appTextStyle(.paragraph)
        }
        .accessibilityElement(children: .contain)
      }
    }
    .accessibilityIdentifier("privacyPolicyScreen")
  }
}
