import SwiftUI

struct ResultsView: View {
    let result: GameResult
    let returnToMenu: () -> Void
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Text(result.outcome == .won ? "Victory" : "Game Over")
                    .appTextStyle(.h1)
                    .foregroundStyle(AppTheme.Colors.highlight)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("resultsTitle")
                VStack(spacing: 8) {
                    Text("Score: \(result.score)")
                        .appTextStyle(.h2)
                        .accessibilityLabel("Final score")
                        .accessibilityValue("\(result.score)")
                        .accessibilityIdentifier("resultsScore")
                    Text("Level 1").appTextStyle(.h3)
                    Text("Time: \(result.elapsedTime.formatted(.number.precision(.fractionLength(1)))) seconds")
                        .appTextStyle(.h3)
                        .accessibilityIdentifier("resultsTime")
                    Text(result.outcome == .won ? "Your run is complete." : "Try again and master the hookshot.")
                        .appTextStyle(.paragraph)
                        .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .appSurface()
                resultActionButton
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden()
        .appNavigationStyle()
    }

    @ViewBuilder
    private var resultActionButton: some View {
        if result.outcome == .won {
            Button("Return to Menu", action: returnToMenu)
                .buttonStyle(AppPrimaryButtonStyle())
                .accessibilityLabel("Return to Main Menu")
                .accessibilityIdentifier("resultsReturnToMenuButton")
        } else {
            Button("Return to Menu", action: returnToMenu)
                .buttonStyle(AppHighlightButtonStyle())
                .accessibilityLabel("Return to Main Menu")
                .accessibilityIdentifier("resultsReturnToMenuButton")
        }
    }
}
