import SwiftUI

struct ResultsView: View {
    let result: GameResult
    let returnToMenu: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text(result.outcome == .won ? "Victory" : "Game Over").font(.largeTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("resultsTitle")
            Text("Score: \(result.score)")
                .accessibilityLabel("Final score")
                .accessibilityValue("\(result.score)")
                .accessibilityIdentifier("resultsScore")
            Button("Return to Menu", action: returnToMenu)
                .accessibilityLabel("Return to Main Menu")
                .accessibilityIdentifier("resultsReturnToMenuButton")
        }
        .navigationBarBackButtonHidden()
    }
}
