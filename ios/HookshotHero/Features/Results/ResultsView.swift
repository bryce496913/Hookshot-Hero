import SwiftUI

struct ResultsView: View {
    let result: GameResult
    let returnToMenu: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text(result.didWin ? "Victory" : "Game Over").font(.largeTitle)
            Text("Score: \(result.score)")
            Button("Return to Menu", action: returnToMenu)
        }
        .navigationBarBackButtonHidden()
    }
}
