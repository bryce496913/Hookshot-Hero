import SwiftUI

struct CreditsLicensesView: View {
  private let codeLicense: String

  init(bundle: Bundle = .main) {
    codeLicense = bundle.url(forResource: "Hookshot-Hero-MIT", withExtension: "txt")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
      ?? "The Hookshot Hero license text is unavailable."
  }

  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          creditSection(
            heading: "Hookshot Hero Code",
            rows: [
              ("Copyright", "Copyright (c) 2023 Jerry Hsiung"),
              ("License", "MIT License"),
            ])

          DisclosureGroup("Read the MIT License") {
            Text(codeLicense)
              .appTextStyle(.paragraph)
              .padding(.top, 12)
          }
          .tint(AppTheme.Colors.accent)

          creditSection(
            heading: "Third-Party Artwork",
            rows: [
              ("Work", "Spinning Gold Coin"),
              ("Creator", "morgan3d"),
              ("Bundled artwork", "goldCoin1.png through goldCoin9.png"),
              ("License", "Creative Commons Attribution 3.0"),
              ("Changes", "Nine supplied frames are stored separately and animated by the app."),
            ],
            source: URL(string: "https://opengameart.org/content/spinning-gold-coin"),
            license: URL(string: "https://creativecommons.org/licenses/by/3.0/legalcode"))

          creditSection(
            heading: "LPC Heroine / Lidia",
            rows: [
              ("Creator", "Yamilian"),
              ("Bundled artwork", "lidia.png"),
              ("License", "Owner selection pending (CC BY-SA 3.0 or GPL 3.0)"),
              ("Changes", "The stored sheet is unchanged; frames are cropped at runtime."),
            ],
            source: URL(string: "https://opengameart.org/content/lpc-heroine"))

          Text("Additional bundled artwork is undergoing provenance and license verification and is not yet cleared for distribution.")
            .appTextStyle(.paragraph)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
      }
    }
    .navigationTitle("Credits & Licenses")
    .appNavigationStyle()
    .accessibilityIdentifier("creditsLicensesScreen")
  }

  @ViewBuilder
  private func creditSection(
    heading: String,
    rows: [(String, String)],
    source: URL? = nil,
    license: URL? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(heading).appTextStyle(.h2)
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        VStack(alignment: .leading, spacing: 2) {
          Text(row.0).font(.caption).foregroundStyle(.secondary)
          Text(row.1).appTextStyle(.paragraph)
        }
      }
      if let source { Link("Source", destination: source) }
      if let license { Link("License text", destination: license) }
    }
  }
}
