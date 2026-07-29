import SwiftUI

struct HelpView: View {
    let dismiss: () -> Void
    var body: some View {
        List {
            Section("Foundation controls") {
                Text("The temporary player marker demonstrates SpriteKit integration. Final touch controls and level rules will be migrated in later slices.")
            }
            Button("Done", action: dismiss).accessibilityIdentifier("helpDoneButton")
        }
        .navigationTitle("Help")
    }
}
