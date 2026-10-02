import SwiftUI

struct PrivacyPolicyView: View {
  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Privacy Policy")
            .font(.largeTitle.bold())
            .foregroundStyle(AppTheme.Colors.text)
            .accessibilityAddTraits(.isHeader)
          Text("Effective \(PrivacyPolicyContent.effectiveDate)")
            .font(.body)
            .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
          Text(PrivacyPolicyContent.introduction)
            .font(.body)
            .foregroundStyle(AppTheme.Colors.text)
          ForEach(PrivacyPolicyContent.sections) { section in
            VStack(alignment: .leading, spacing: 8) {
              Text(section.title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.Colors.text)
                .accessibilityAddTraits(.isHeader)
              Text(section.body)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.text)
            }
            .accessibilityElement(children: .contain)
          }
        }
        .padding(24)
      }
    }
    .navigationTitle("Privacy Policy")
    .appNavigationStyle()
    .accessibilityIdentifier("privacyPolicyScreen")
  }
}
