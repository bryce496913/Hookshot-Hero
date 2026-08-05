import SwiftUI

struct HelpView: View {
    let dismiss: () -> Void
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Help")
                        .appTextStyle(.h1)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Level 1 controls").appTextStyle(.h2)
                        Text("Direction pad").appTextStyle(.h3).foregroundStyle(AppTheme.Colors.accent)
                        Text("Use the direction pad to move Lidia one grid cell at a time. Hold a direction to keep moving.")
                            .appTextStyle(.paragraph)
                        Text("Grapple").appTextStyle(.h3).foregroundStyle(AppTheme.Colors.highlight)
                        Text("Face a wall and tap Grapple to pull toward it, cross lava safely, collect items, and destroy mines.")
                            .appTextStyle(.paragraph)
                    }
                    .padding(16)
                    .appSurface()
                    Button("Done", action: dismiss)
                        .buttonStyle(AppPrimaryButtonStyle())
                        .accessibilityIdentifier("helpDoneButton")
                }
                .padding(24)
            }
        }
        .navigationTitle("Help")
        .appNavigationStyle()
    }
}
