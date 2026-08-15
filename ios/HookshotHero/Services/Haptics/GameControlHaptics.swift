import UIKit

@MainActor
protocol GameControlHaptics {
  func directionEngaged()
  func directionChanged()
  func grappleAimingDirectionChanged()
  func grappleFired()
}

@MainActor
struct UIKitGameControlHaptics: GameControlHaptics {
  func directionEngaged() { selectionFeedback() }
  func directionChanged() { selectionFeedback() }
  func grappleAimingDirectionChanged() { selectionFeedback() }

  func grappleFired() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred()
  }

  private func selectionFeedback() {
    let generator = UISelectionFeedbackGenerator()
    generator.prepare()
    generator.selectionChanged()
  }
}
