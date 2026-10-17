import SwiftUI

struct HighScoresView: View {
  let entries: [HighScoreEntry]

  var body: some View {
    AppSecondaryScreen(title: "High Scores") {
      Text("Best local scores").appTextStyle(.h3)
        .foregroundStyle(AppTheme.Colors.textSecondary)
      AppCard {
        Text(HighScoreScoring.explanation).appTextStyle(.caption)
          .foregroundStyle(AppTheme.Colors.textSecondary)
          .accessibilityIdentifier("highScoresExplanation")
      }
      if entries.isEmpty {
        AppCard(style: .hero) {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Image(systemName: "trophy.fill").appTextStyle(.h1)
              .foregroundStyle(AppTheme.Colors.accent).accessibilityHidden(true)
            Text("No scores yet.").appTextStyle(.h2).accessibilityAddTraits(.isHeader)
            Text("Finish a game and enter your initials to set your first high score.")
              .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.textSecondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("highScoresEmptyState")
      } else {
        ForEach(Array(HighScoreScoring.topEntries(entries).enumerated()), id: \.element.id) { index, entry in
          HighScoreRow(rank: index + 1, entry: entry)
        }
      }
      Text("Your best \(HighScoreScoring.maximumEntries) scores are stored on this device.")
        .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textMuted)
    }
    .accessibilityIdentifier("highScoresScreen")
  }
}

struct HighScoreRow: View {
  let rank: Int
  let entry: HighScoreEntry
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var accessibilitySummary: String {
    "Rank \(rank). \(entry.initials == "---" ? "Unknown initials" : entry.initials). \(entry.context). Final score \(entry.totalScore). Game score \(entry.rawScore). "
      + "Time bonus \(entry.timeBonus). Time \(GameDurationFormatter.spokenString(for: entry.elapsedTime))."
  }

  var body: some View {
    AppCard(style: rank == 1 ? .hero : (rank <= 3 ? .elevated : .standard)) {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) { heading }
        } else {
          HStack(alignment: .top, spacing: AppTheme.Spacing.md) { heading }
        }
        AppDivider()
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.md) { details }
        } else {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) { details }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityIdentifier("highScoreRow\(rank)")
  }

  @ViewBuilder private var heading: some View {
    Text("#\(rank)").appTextStyle(.h3)
      .foregroundStyle(rank == 1 ? AppTheme.Colors.highlight : AppTheme.Colors.accent)
    Text(entry.initials).appTextStyle(.h1).fontDesign(.monospaced)
      .lineLimit(1).minimumScaleFactor(0.7)
      .foregroundStyle(AppTheme.Colors.accent)
    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
      Text("FINAL SCORE").appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
      Text("\(entry.totalScore.formatted()) pts").appTextStyle(.h2).monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder private var details: some View {
    Text(entry.context).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
    HighScoreDetail(title: "Game Score", value: entry.rawScore.formatted())
    HighScoreDetail(title: "Time Bonus", value: "+\(entry.timeBonus.formatted())")
    HighScoreDetail(title: "Time", value: GameDurationFormatter.displayString(for: entry.elapsedTime),
                    isTime: true)
  }
}

/// Shared score detail; numeric values can wrap at large text sizes instead of truncating.
struct HighScoreDetail: View {
  let title: String
  let value: String
  var isTime = false
  var identifier: String? = nil
  var spokenValue: String? = nil
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) { content }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) { content }
      }
    }
  }

  @ViewBuilder private var content: some View {
    Text(title).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
      .accessibilityHidden(true)
    Text(value).appTextStyle(.paragraph).monospacedDigit()
      .lineLimit(isTime ? 1 : nil).minimumScaleFactor(isTime ? 0.5 : 1)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
      .accessibilityLabel(title).accessibilityValue(spokenValue ?? value)
      .accessibilityIdentifier(identifier ?? "")
  }
}
