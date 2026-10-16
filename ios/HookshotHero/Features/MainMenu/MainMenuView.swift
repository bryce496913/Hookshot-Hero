import SwiftUI

struct MainMenuView: View {
  let isLevelSelectUnlocked: Bool
  let play: () -> Void
  let playLevel: (LevelID) -> Void
  let settings: () -> Void
  let help: () -> Void
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: AppTheme.Spacing.lg) {
          VStack(spacing: AppTheme.Spacing.md) {
            AppIconHeroView(size: min(210, max(160, geometry.size.height * 0.27)))
            VStack(spacing: AppTheme.Spacing.sm) {
              Text("Hookshot Hero")
                .appTextStyle(.heroTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
              Text("Grapple through the dungeons.")
                .appTextStyle(.paragraph)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            }
          }
          VStack(spacing: AppTheme.Spacing.sm) {
            Button(action: play) { Label("Play", systemImage: "play.fill") }
              .buttonStyle(AppPrimaryButtonStyle())
              .accessibilityIdentifier("playButton")
            if isLevelSelectUnlocked {
              NavigationLink {
                LevelSelectView(playLevel: playLevel)
              } label: {
                Label("Level Select", systemImage: "square.grid.2x2")
              }
              .buttonStyle(AppSecondaryButtonStyle())
              .accessibilityIdentifier("levelSelectButton")
            }
          }
          if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppTheme.Spacing.sm) { utilities }
          } else {
            HStack(spacing: AppTheme.Spacing.md) { utilities }
          }
        }
        .frame(maxWidth: 440)
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }
      .scrollIndicators(.hidden)
    }
    .appScreenBackground()
    .navigationBarBackButtonHidden()
    .appNavigationStyle()
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder private var utilities: some View {
    utility("Settings", systemImage: "gearshape", identifier: "settingsButton", action: settings)
    utility("Help", systemImage: "questionmark.circle", identifier: "helpButton", action: help)
  }

  private func utility(
    _ title: String, systemImage: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage).appTextStyle(.caption)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, minHeight: AppTheme.Layout.minimumHitTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(AppSurfaceButtonStyle(cornerRadius: AppTheme.Radius.control))
    .foregroundStyle(AppTheme.Colors.textSecondary)
    .appSurface(cornerRadius: AppTheme.Radius.control)
    .accessibilityIdentifier(identifier)
    .accessibilityLabel(title)
  }
}

struct LevelSelectionOption: Identifiable, Equatable {
  let number: Int
  let levelID: LevelID

  var id: LevelID { levelID }
  var title: String { levelID.displayName }
  var isEndingArea: Bool { levelID == .countryRoad || levelID == .heroWelcome }
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

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
          Text("Choose your adventure")
            .appTextStyle(.h1).accessibilityAddTraits(.isHeader)
          Text("Enter any dungeon or visit the journey’s end.")
            .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.textSecondary)
        }
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
          spacing: AppTheme.Spacing.md
        ) {
          ForEach(Self.levels) { level in
            Button { playLevel(level.levelID) } label: {
              LevelSelectionCard(level: level)
            }
            .buttonStyle(AppSurfaceButtonStyle(
              cornerRadius: level.isEndingArea ? AppTheme.Radius.hero : AppTheme.Radius.card))
            .accessibilityLabel(level.title)
            .accessibilityHint(level.isEndingArea ? "Enter ending area" : "Enter dungeon")
            .accessibilityIdentifier(level.accessibilityIdentifier)
          }
        }
      }
      .frame(maxWidth: 640)
      .padding(AppTheme.Spacing.lg)
      .frame(maxWidth: .infinity)
    }
    .appScreenBackground()
    .navigationTitle("Level Select")
    .navigationBarTitleDisplayMode(.inline)
    .appNavigationStyle()
  }
}

private struct LevelSelectionCard: View {
  let level: LevelSelectionOption

  var body: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
      HStack {
        Text(level.isEndingArea ? "EPILOGUE" : String(format: "%02d", level.number))
          .appTextStyle(.caption).fontWeight(.bold)
          .foregroundStyle(level.isEndingArea ? AppTheme.Colors.highlight : AppTheme.Colors.accent)
          .padding(.horizontal, AppTheme.Spacing.sm).padding(.vertical, AppTheme.Spacing.xs)
          .background(AppTheme.Colors.backgroundElevated, in: Capsule())
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").appTextStyle(.caption)
          .foregroundStyle(AppTheme.Colors.textMuted)
      }
      Text(level.title).appTextStyle(.h3)
        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
      Text(level.isEndingArea ? "Journey’s end" : "Dungeon")
        .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
    }
    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    .padding(AppTheme.Spacing.md)
    .appSurface(style: level.isEndingArea ? .hero : .elevated)
    .contentShape(RoundedRectangle(
      cornerRadius: level.isEndingArea ? AppTheme.Radius.hero : AppTheme.Radius.card))
    .accessibilityElement(children: .ignore)
  }
}
