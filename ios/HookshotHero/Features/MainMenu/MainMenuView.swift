import SwiftUI

struct MainMenuView: View {
    let play: () -> Void
    let settings: () -> Void
    let help: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "scope")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text("Hookshot Hero")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Native iOS development build")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            menuButton("Play", systemImage: "play.fill", action: play)
                .accessibilityIdentifier("playButton")
            menuButton("Settings", systemImage: "gearshape", action: settings)
                .accessibilityIdentifier("settingsButton")
            menuButton("Help", systemImage: "questionmark.circle", action: help)
                .accessibilityIdentifier("helpButton")
            Spacer()
        }
        .padding(.horizontal, 32)
        .safeAreaPadding(.bottom)
        .navigationBarBackButtonHidden()
        .accessibilityElement(children: .contain)
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: systemImage).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(title)
    }
}
