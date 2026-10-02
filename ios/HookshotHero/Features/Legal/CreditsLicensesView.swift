import SwiftUI

struct CreditsLicensesView: View {
  private let notice: AttributedString

  init(bundle: Bundle = .main) {
    let text = bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
      ?? "Third-party notices are unavailable. Distribution must not proceed without them."
    notice = (try? AttributedString(markdown: text)) ?? AttributedString(text)
  }

  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        Text(notice)
          .appTextStyle(.paragraph)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(24)
      }
    }
    .navigationTitle("Credits & Licenses")
    .appNavigationStyle()
    .accessibilityIdentifier("creditsLicensesScreen")
  }
}
