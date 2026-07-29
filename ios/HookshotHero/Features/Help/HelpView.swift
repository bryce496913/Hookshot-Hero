import SwiftUI

struct HelpView: View {
    let dismiss: () -> Void
    var body: some View {
        List {
            Section("Level 1 controls") {
                Text("Use the direction pad to move Lidia one grid cell at a time. Hold a direction to keep moving. Face a wall and tap Grapple to pull toward it, cross lava safely, collect items, and destroy mines.")
            }
            Button("Done", action: dismiss).accessibilityIdentifier("helpDoneButton")
        }
        .navigationTitle("Help")
    }
}
