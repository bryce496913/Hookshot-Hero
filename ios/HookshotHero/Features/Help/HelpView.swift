import SwiftUI

struct HelpView: View {
  let dismiss: () -> Void

  var body: some View {
    AppSecondaryScreen(title: "Help") {
      AppCard(style: .hero) {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
          Text("The Story").appTextStyle(.caption).fontWeight(.semibold)
            .foregroundStyle(AppTheme.Colors.accent).accessibilityAddTraits(.isHeader)
          Text("Into the Dungeons").appTextStyle(.h1).accessibilityAddTraits(.isHeader)
          Text(
            "In a realm shrouded in mystery, Lidia and Shura, brave and determined heroines, embark on a perilous journey. Drawn by the allure of hidden treasures and ancient secrets, they fearlessly enter the dungeons."
          )
          .appTextStyle(.paragraph)
          Text(
            "Empowered by the legendary Hookshot, a grappling hook fused to her arm, Lidia defies danger and navigates treacherous terrain. With each triumph over enemies and each precious treasure recovered, she moves closer to the ultimate prize."
          )
          .appTextStyle(.paragraph)
          Text(
            "Driven by unwavering bravery, Lidia's quest for glory unfolds as she unravels the depths of the dungeons, leaving an indelible mark upon the annals of Eldoria's history."
          )
          .appTextStyle(.paragraph)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("storyIntro")
      AppInformationSection(title: "Getting Started") {
        helpSection(
          "Controls", body: "Use the movement and Grapple controls together as you explore.",
          identifier: "helpControlsSection")
      }
      AppInformationSection(title: "Movement & Grapple") {
        helpSection(
          "Movement",
          body:
            "Drag the joystick to move. Holding it continues movement; releasing it stops movement. Held movement pauses during a Grapple and resumes afterward if the joystick remains held.",
          identifier: "helpMovementSection")
        helpSection(
          "Grapple",
          body:
            "Tap Grapple to fire in the direction you are facing, or drag and release to choose a direction. Grapple onto walls and visible doors to cross hazards. The hook retracts when it reaches its maximum range. Contact with a bomb destroys it and retracts the hook.",
          identifier: "helpGrappleSection")
      }
      AppInformationSection(title: "Hazards & Items") {
        helpSection(
          "Lava and Hazards",
          body:
            "Lava damages you when you meaningfully enter it and returns you to safety; brushing an edge is more forgiving. Bombs and enemies also cost health, so plan a safe route.",
          identifier: "helpHazardsSection")
        helpSection(
          "Items",
          body:
            "Coins add to your score. Cabbage barrels restore health up to your maximum. Bombs and mines hurt on contact but can be destroyed with the Grapple. Treasure chests open when approached and may award health, points, and guidance.",
          identifier: "helpItemsSection")
      }
      AppInformationSection(title: "Enemies & Progression") {
        helpSection(
          "Enemies and Bosses",
          body:
            "Skeletons pursue you on the ground, while Flying Terrors attack from the air. Strike enemies with the Grapple, avoid their attacks, and defeat bosses to unlock the way forward.",
          identifier: "helpEnemiesSection")
        helpSection(
          "Progression",
          body:
            "The campaign branches after Level 4. Explore either route; the paths reconnect later as the journey continues.",
          identifier: "helpProgressionSection")
        helpSection(
          "Final Route",
          body:
            "After the final dungeon boss, keep going: the adventure continues beyond the dungeon into the ending areas.",
          identifier: "helpFinalRouteSection")
      }
      AppInformationSection(title: "Pause & Support") {
        helpSection(
          "Pause / Resume",
          body:
            "Use Pause during play to stop the action. Choose Resume to continue, or Return to Menu to leave the current run safely.",
          identifier: "helpPauseSection")
        NavigationLink { SupportView() } label: {
          AppNavigationRow(title: "Support", systemImage: "lifepreserver")
        }
        .buttonStyle(AppSurfaceButtonStyle(cornerRadius: AppTheme.Radius.control))
        .accessibilityLabel("Support").accessibilityIdentifier("helpSupportLink")
        AppDivider()
        NavigationLink { PrivacyPolicyView() } label: {
          AppNavigationRow(title: "Privacy Policy", systemImage: "shield")
        }
        .buttonStyle(AppSurfaceButtonStyle(cornerRadius: AppTheme.Radius.control))
        .accessibilityLabel("Privacy Policy").accessibilityIdentifier("helpPrivacyPolicyLink")
      }
      Button("Done", action: dismiss).buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("helpDoneButton")
    }
  }

  private func helpSection(_ title: String, body: String, identifier: String) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      Text(title).appTextStyle(.h3).accessibilityAddTraits(.isHeader)
      Text(body).appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.textSecondary)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier)
  }
}
