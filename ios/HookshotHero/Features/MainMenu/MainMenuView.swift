import SwiftUI

struct MainMenuView: View {
  let play: () -> Void
  let playLevel: (LevelID) -> Void
  let settings: () -> Void
  let help: () -> Void

  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 18) {
          Spacer(minLength: 20)
          VStack(spacing: 12) {
            Image(systemName: "scope")
              .font(.system(size: 54, weight: .bold, design: .rounded))
              .foregroundStyle(AppTheme.Colors.highlight)
              .accessibilityHidden(true)
            Text("Hookshot Hero")
              .appTextStyle(.h1)
              .multilineTextAlignment(.center)
              .accessibilityAddTraits(.isHeader)
          }
          .frame(maxWidth: .infinity)
          .padding(24)
          .appSurface()
          Spacer(minLength: 12)
          menuButton("Play", systemImage: "play.fill", style: .primary, action: play)
            .accessibilityIdentifier("playButton")
          NavigationLink {
            LevelSelectView(playLevel: playLevel)
          } label: {
            Label("Level Select", systemImage: "list.number")
          }
          .buttonStyle(AppSecondaryButtonStyle())
          .accessibilityIdentifier("levelSelectButton")
          menuButton("Settings", systemImage: "gearshape", style: .secondary, action: settings)
            .accessibilityIdentifier("settingsButton")
          menuButton("Help", systemImage: "questionmark.circle", style: .secondary, action: help)
            .accessibilityIdentifier("helpButton")
          Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, minHeight: 640)
        .padding(.horizontal, 32)
        .safeAreaPadding(.bottom)
      }
    }
    .navigationBarBackButtonHidden()
    .appNavigationStyle()
    .accessibilityElement(children: .contain)
  }

  private enum MenuButtonStyle { case primary, secondary }

  @ViewBuilder
  private func menuButton(
    _ title: String, systemImage: String, style: MenuButtonStyle, action: @escaping () -> Void
  ) -> some View {
    let button = Button(action: action) { Label(title, systemImage: systemImage) }
      .accessibilityLabel(title)
    switch style {
    case .primary: button.buttonStyle(AppPrimaryButtonStyle())
    case .secondary: button.buttonStyle(AppSecondaryButtonStyle())
    }
  }
}

struct LevelSelectionOption: Identifiable, Equatable {
  let number: Int
  let levelID: LevelID

  var id: LevelID { levelID }
  var title: String { levelID.displayName }
  var accessibilityIdentifier: String { "level\(number)Button" }
}

struct LevelSelectView: View {
  let playLevel: (LevelID) -> Void
  static let levels: [LevelSelectionOption] = [
    .init(number: 1, levelID: .levelOne),
    .init(number: 2, levelID: .levelTwo),
    .init(number: 3, levelID: .levelThree),
    .init(number: 4, levelID: .levelFour),
    .init(number: 5, levelID: .levelFive),
    .init(number: 6, levelID: .levelSix),
    .init(number: 7, levelID: .levelSeven),
    .init(number: 8, levelID: .levelEight),
    .init(number: 9, levelID: .levelNine),
    .init(number: 10, levelID: .levelTen),
    .init(number: 11, levelID: .countryRoad),
    .init(number: 12, levelID: .heroWelcome),
  ]

  var body: some View {
    ZStack {
      AppTheme.Colors.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 14) {
          Text("Level Select").appTextStyle(.h1).accessibilityAddTraits(.isHeader)
          Text("Start directly in any level.")
            .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.text.opacity(0.7))
          ForEach(Self.levels) { level in
            Button(level.title) { playLevel(level.levelID) }
              .buttonStyle(AppPrimaryButtonStyle())
              .accessibilityIdentifier(level.accessibilityIdentifier)
          }
        }.padding(24)
      }
    }
    .navigationTitle("Levels")
    .appNavigationStyle()
  }
}
