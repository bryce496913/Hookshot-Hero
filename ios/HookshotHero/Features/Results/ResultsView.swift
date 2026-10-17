import SwiftUI

struct ResultsView: View {
  let result: GameResult
  let returnToMenu: () -> Void
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  private var won: Bool { result.outcome == .won }
  private var elapsed: String {
    GameDurationFormatter.displayString(for: result.elapsedTime)
  }

  var body: some View {
    AppStateScreen {
      AppCard(style: won ? .hero : .standard) {
        VStack(spacing: AppTheme.Spacing.md) {
          Label(won ? "Run complete" : "Run ended",
                systemImage: won ? "flag.checkered" : "shield.lefthalf.filled")
            .appTextStyle(.caption).fontWeight(.semibold)
            .foregroundStyle(won ? AppTheme.Colors.highlight : AppTheme.Colors.textSecondary)
            .accessibilityHidden(true)
          Text(won ? "Victory" : "Game Over")
            .appTextStyle(.heroTitle)
            .foregroundStyle(won ? AppTheme.Colors.accent : AppTheme.Colors.text)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resultsTitle")
          Text(result.levelID.displayName).appTextStyle(.h3)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .accessibilityLabel(result.levelID.displayName)
            .accessibilityIdentifier("resultsLevel")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
      }
      if let entry = rankedEntry {
        AppCard(style: .elevated) {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HighScoreDetail(title: "Game Score", value: entry.rawScore.formatted(),
                            identifier: "resultsScore", spokenValue: String(entry.rawScore))
            HighScoreDetail(title: "Time Bonus", value: "+\(entry.timeBonus.formatted())",
                            identifier: "resultsTimeBonus", spokenValue: String(entry.timeBonus))
            AppDivider()
            Text("FINAL SCORE").appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
              .accessibilityHidden(true)
            Text(entry.totalScore.formatted()).appTextStyle(.h1).monospacedDigit()
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityLabel("Final score").accessibilityValue(String(entry.totalScore))
              .accessibilityIdentifier("resultsFinalScore")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        timeStat
        if let rank = result.leaderboardRank, rank > 0, rank <= HighScoreScoring.maximumEntries {
          Text(rank == 1 ? "New High Score" : "Top \(HighScoreScoring.maximumEntries) Run")
            .appTextStyle(.h3).foregroundStyle(AppTheme.Colors.accent)
            .accessibilityIdentifier("resultsRankingStatus")
        }
      } else if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: AppTheme.Spacing.md) { stats }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: AppTheme.Spacing.md) { stats }
          VStack(spacing: AppTheme.Spacing.md) { stats }
        }
      }
      Text(won ? "Your run is complete." : "Try again and master the hookshot.")
        .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.textSecondary)
        .multilineTextAlignment(.center)
      if won {
        menuButton.buttonStyle(AppPrimaryButtonStyle())
      } else {
        menuButton.buttonStyle(AppSecondaryButtonStyle())
      }
    }
  }

  private var rankedEntry: HighScoreEntry? {
    result.outcome == .won && result.levelID == .heroWelcome ? result.leaderboardEntry : nil
  }

  @ViewBuilder private var stats: some View {
    ResultStat(title: "SCORE", value: result.score.formatted(),
               accessibilityLabel: "Final score", accessibilityValue: String(result.score),
               identifier: "resultsScore")
    timeStat
  }

  private var timeStat: some View {
    ResultStat(title: "TIME", value: elapsed,
               accessibilityLabel: "Elapsed time",
               accessibilityValue: GameDurationFormatter.spokenString(for: result.elapsedTime),
               identifier: "resultsTime", keepsValueOnOneLine: true)
  }

  private var menuButton: some View {
    Button("Return to Menu", action: returnToMenu)
      .accessibilityLabel("Return to Main Menu")
      .accessibilityIdentifier("resultsReturnToMenuButton")
  }
}

private struct ResultStat: View {
  let title: String
  let value: String
  let accessibilityLabel: String
  let accessibilityValue: String
  let identifier: String
  var keepsValueOnOneLine = false

  var body: some View {
    AppCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
        Text(title).appTextStyle(.caption).fontWeight(.semibold)
          .foregroundStyle(AppTheme.Colors.textSecondary).accessibilityHidden(true)
        Text(value).appTextStyle(.h1).monospacedDigit()
          .lineLimit(keepsValueOnOneLine ? 1 : nil)
          .minimumScaleFactor(keepsValueOnOneLine ? 0.5 : 1)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel(accessibilityLabel).accessibilityValue(accessibilityValue)
          .accessibilityIdentifier(identifier)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
