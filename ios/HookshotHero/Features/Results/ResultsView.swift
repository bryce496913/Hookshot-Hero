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
            Button("Return to Menu", action: returnToMenu)
                .accessibilityIdentifier("resultsReturnToMenuButton")
        }
        .navigationBarBackButtonHidden()
    }
}
