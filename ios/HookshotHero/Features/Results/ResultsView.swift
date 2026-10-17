import SwiftUI

struct ResultsView: View {
  let result: GameResult
  let returnToMenu: () -> Void
  var submitScore: (String) -> HighScoreEntry? = { _ in nil }
  var savePending = false
  var retrySave: () -> Void = {}
  @State private var savedEntry: HighScoreEntry?
  @State private var submissionMessage: String?
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
      if let entry = result.highScoreCandidate {
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
      } else if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: AppTheme.Spacing.md) { stats }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: AppTheme.Spacing.md) { stats }
          VStack(spacing: AppTheme.Spacing.md) { stats }
        }
      }
      if let candidate = result.highScoreCandidate {
        if let savedEntry {
          AppCard(style: .elevated) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
              Text("\(savedEntry.initials) — score entered")
                .appTextStyle(.h2).fontDesign(.monospaced).accessibilityIdentifier("highScoreSavedConfirmation")
              Text(savePending ? "Score entered. Saving on this device is pending." : "Score saved on this device.")
                .appTextStyle(.caption)
              if savePending {
                Button("Retry Save", action: retrySave).buttonStyle(AppSecondaryButtonStyle())
                  .accessibilityIdentifier("highScoreRetrySaveButton")
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        } else if let rank = result.leaderboardRank {
          HighScoreInitialsView(rank: rank) { initials in
            if let entry = submitScore(initials) {
              savedEntry = entry
              submissionMessage = nil
            } else {
              submissionMessage = "This score could not be entered. You can return to the menu."
            }
          }
        } else {
          Text("Score did not make the Top \(HighScoreScoring.maximumEntries).")
            .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
            .accessibilityIdentifier("highScoreNonQualifier")
        }
        if let submissionMessage { Text(submissionMessage).appTextStyle(.caption) }
        // Outcome-specific scoring is already resolved by the domain policy.
        Text(candidate.outcome == .campaignVictory ? "Campaign completion bonus included."
          : candidate.outcome == .gameOver ? "Game score only. No time bonus for Game Over."
          : "Game score only. This was a direct level run.")
          .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textMuted)
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

/// One accessible native text field drives three visible arcade slots.
private struct HighScoreInitialsView: View {
  let rank: Int
  let submit: (String) -> Void
  @State private var initials = ""
  @State private var submitted = false
  @FocusState private var focused: Bool

  var body: some View {
    AppCard(style: .hero) {
      VStack(spacing: AppTheme.Spacing.md) {
        Text(rank == 1 ? "NEW HIGH SCORE" : "TOP \(HighScoreScoring.maximumEntries) SCORE")
          .appTextStyle(.h3).foregroundStyle(AppTheme.Colors.accent)
          .accessibilityIdentifier("resultsRankingStatus")
        Text("#\(rank)").appTextStyle(.h2).monospacedDigit()
          .accessibilityLabel("Provisional rank \(rank)")
          .accessibilityIdentifier("highScoreProvisionalRank")
        Text("ENTER INITIALS").appTextStyle(.caption).accessibilityAddTraits(.isHeader)
        ZStack {
          HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(0..<3) { index in
              Text(letter(at: index)).appTextStyle(.h1).fontDesign(.monospaced)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AppTheme.Colors.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(
                  focused ? AppTheme.Colors.accent : AppTheme.Colors.divider, lineWidth: 1) }
                .accessibilityLabel("Initial \(index + 1)")
                .accessibilityValue(letter(at: index))
                .accessibilityIdentifier("highScoreInitial\(index + 1)")
            }
          }.allowsHitTesting(false)
          TextField("", text: $initials)
            .keyboardType(.asciiCapable).textInputAutocapitalization(.characters)
            .autocorrectionDisabled().submitLabel(.done).focused($focused)
            .foregroundStyle(.clear).tint(.clear)
            .frame(minHeight: 56).contentShape(Rectangle())
            .accessibilityLabel("Three initials, letters A to Z")
            .accessibilityIdentifier("highScoreInitialsEntry")
            .onChange(of: initials) { _, value in initials = HighScoreInitials.constrained(value) }
            .onSubmit(save)
        }
        Text("Enter three letters, A–Z.").appTextStyle(.caption)
          .foregroundStyle(AppTheme.Colors.textSecondary)
        Button("SAVE SCORE", action: save).buttonStyle(AppPrimaryButtonStyle())
          .disabled(submitted || HighScoreInitials.validated(initials) == nil)
          .accessibilityIdentifier("highScoreSubmitButton")
      }
    }
  }

  private func letter(at index: Int) -> String {
    let letters = Array(initials)
    return index < letters.count ? String(letters[index]) : "_"
  }

  private func save() {
    guard !submitted, let valid = HighScoreInitials.validated(initials) else { return }
    submitted = true
    focused = false
    submit(valid)
  }
}
