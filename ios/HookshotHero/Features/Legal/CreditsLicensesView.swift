import SwiftUI

struct CreditsLicensesView: View {
  private let codeLicense: String
  private let audioNotice: String

  init(bundle: Bundle = .main) {
    codeLicense = bundle.url(forResource: "Hookshot-Hero-MIT", withExtension: "txt")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
      ?? "The Hookshot Hero license text is unavailable."
    let notice = bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    audioNotice = notice?.components(separatedBy: "## Native audio — unresolved distribution blockers").last
      ?? "Audio provenance and redistribution rights remain unresolved."
  }

  var body: some View {
    AppSecondaryScreen(title: "Credits & Licenses") {
      creditSection(
        heading: "Hookshot Hero Code",
        rows: [
          ("Copyright", "Copyright (c) 2023 Jerry Hsiung"),
          ("License", "MIT License"),
        ])

      AppInformationSection(title: "License details") {
        DisclosureGroup("Read the MIT License") {
          Text(codeLicense).appTextStyle(.paragraph).padding(.top, AppTheme.Spacing.sm)
        }
        .tint(AppTheme.Colors.accent)
        .accessibilityIdentifier("codeLicenseDisclosure")
      }

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

      AppSectionHeader(title: "Original Music & Sound")
      AppCard {
        Text("All original Java WAV files are bundled unchanged. Audio provenance and redistribution rights remain unresolved; these credits do not establish distribution clearance.")
          .appTextStyle(.paragraph)
          .accessibilityIdentifier("audioLicenseStatus")
      }
      creditSection(heading: "Scarey Atmospheres Ch 2", rows: [
        ("Creator / attribution lead", "David Fesliyan (README lead)"),
        ("Bundled audio", "Atmosphere.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://www.fesliyanstudios.com/royalty-free-music/download/scarey-atmospheres-ch-2/163"))
      creditSection(heading: "Pretty Maiden", rows: [
        ("Creator / attribution lead", "Mageonduty"),
        ("Bundled audio", "pretty-maiden-mageonduty.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/pretty-maiden-medievalfantasy-game-cheerful-opening"))
      creditSection(heading: "Lava Area Theme", rows: [
        ("Creator / attribution lead", "Wolfgang_"),
        ("Bundled audio", "lava.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/lava-area-theme"))
      creditSection(heading: "Female RPG Voice Starter Pack", rows: [
        ("Creator / attribution lead", "cicifyre"),
        ("Bundled audio", "t3-healed3.wav, t3-damaged1.wav, t3-attack3.wav, t2-healed3.wav, t2-damaged1.wav, t2-attack3.wav, t1-healed3.wav, t1-damaged1.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/female-rpg-voice-starter-pack"))
      creditSection(heading: "Whip sound", rows: [
        ("Creator / attribution lead", "Reemax / Tuomo Untinen"),
        ("Bundled audio", "whip.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/whip-sound"))
      creditSection(heading: "7 Eating Crunches", rows: [
        ("Creator / attribution lead", "StarNinjas / Tito"),
        ("Bundled audio", "crunch.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/7-eating-crunches"))
      creditSection(heading: "9 explosion sounds", rows: [
        ("Creator / attribution lead", "Unnamed"),
        ("Bundled audio", "explosion.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/9-explosion-sounds"))
      creditSection(heading: "Monster packs / tutorial", rows: [
        ("Creator / attribution lead", "jalastram / piacenti OR VividReality (exact file mapping unknown)"),
        ("Bundled audio", "ft.wav, skeleton.wav, monsterdamage.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/monster-and-creatures-sound-effects-pack-001"))
      creditSection(heading: "Coin Sound Effect / Mario Coin Sound", rows: [
        ("Creator / attribution lead", "Gaming Sound FX (README uploader lead; original rights holder unknown)"),
        ("Bundled audio", "coin.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://www.youtube.com/watch?v=mQSmVZU5EL4"))
      creditSection(heading: "Frostbite Medieval Soundtrack", rows: [
        ("Creator / attribution lead", "tridentkeep and potentially additional credited contributors"),
        ("Bundled audio", "start.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ], source: URL(string: "https://opengameart.org/content/frostbite-medieval-soundtrack"))
      creditSection(heading: "Unknown", rows: [
        ("Creator / attribution lead", "Unknown"),
        ("Bundled audio", "walk.wav, hit.wav, step.wav"),
        ("Status", "Exact WAV provenance and redistribution clearance unresolved."),
      ])
      AppInformationSection(title: "Audio license details") {
        DisclosureGroup("Read the audio distribution audit") {
          Text(audioNotice).appTextStyle(.paragraph).padding(.top, AppTheme.Spacing.sm)
        }
        .tint(AppTheme.Colors.accent)
        .accessibilityIdentifier("audioLicenseDisclosure")
      }

      AppCard {
        Text("Additional bundled artwork is undergoing provenance and license verification and is not yet cleared for distribution.")
          .appTextStyle(.paragraph)
      }
    }
    .accessibilityIdentifier("creditsLicensesScreen")
  }

  @ViewBuilder
  private func creditSection(
    heading: String,
    rows: [(String, String)],
    source: URL? = nil,
    license: URL? = nil
  ) -> some View {
    AppInformationSection(title: heading) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        VStack(alignment: .leading, spacing: 2) {
          Text(row.0).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
          Text(row.1).appTextStyle(.paragraph)
        }
      }
      if let source { Link("Source", destination: source) }
      if let license { Link("License text", destination: license) }
    }
  }
}
