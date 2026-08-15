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
            Text("Joystick").appTextStyle(.h3).foregroundStyle(AppTheme.Colors.accent)
            Text(
              "Drag the joystick to move in four directions. Hold it to keep moving, and release it to stop."
            )
            .appTextStyle(.paragraph)
            Text("Grapple").appTextStyle(.h3).foregroundStyle(AppTheme.Colors.highlight)
            Text(
              "Tap Grapple to fire in the direction you're facing. Drag from Grapple and release to aim in a different direction."
            )
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
