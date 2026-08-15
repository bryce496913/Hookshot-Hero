import CoreGraphics
import XCTest
@testable import HookshotHero

final class VirtualJoystickControllerTests: XCTestCase {
  private let radius: CGFloat = 40

  func testCenterAndDeadZoneProduceNoDirection() {
    XCTAssertNil(VirtualJoystickController.direction(for: .zero, usableRadius: radius))
    XCTAssertNil(
      VirtualJoystickController.direction(
        for: CGVector(dx: radius * 0.2, dy: 0), usableRadius: radius))
  }

  func testCardinalDirectionsResolve() {
    XCTAssertEqual(direction(0, -30), .up)
    XCTAssertEqual(direction(0, 30), .down)
    XCTAssertEqual(direction(-30, 0), .left)
    XCTAssertEqual(direction(30, 0), .right)
  }

  func testDominantAxisSnappingAndVerticalTieBreak() {
    XCTAssertEqual(direction(30, -20), .right)
    XCTAssertEqual(direction(-20, 30), .down)
    XCTAssertEqual(direction(30, -30), .up)
  }

  func testEnteringAndHoldingDirectionBeginsExactlyOnce() {
    var controller = VirtualJoystickController()
    XCTAssertEqual(
      controller.update(displacement: .init(dx: 30, dy: 0), usableRadius: radius),
      [.beginMove(.right)])
    XCTAssertEqual(controller.update(displacement: .init(dx: 35, dy: 2), usableRadius: radius), [])
  }

  func testDirectionSwitchEndsOldBeforeBeginningNew() {
    var controller = VirtualJoystickController()
    _ = controller.update(displacement: .init(dx: 30, dy: 0), usableRadius: radius)
    XCTAssertEqual(
      controller.update(displacement: .init(dx: 0, dy: 30), usableRadius: radius),
      [.endMove(.right), .beginMove(.down)])
  }

  func testReturningToDeadZoneEndsAndCenters() {
    var controller = VirtualJoystickController()
    _ = controller.update(displacement: .init(dx: -30, dy: 0), usableRadius: radius)
    XCTAssertEqual(controller.update(displacement: .zero, usableRadius: radius), [.endMove(.left)])
    XCTAssertEqual(controller.state, VirtualJoystickState())
  }

  func testReleaseEndsMovement() {
    var controller = VirtualJoystickController()
    _ = controller.update(displacement: .init(dx: 0, dy: -30), usableRadius: radius)
    XCTAssertEqual(controller.cancel(), [.endMove(.up)])
  }

  func testCancellationEndsMovementAndCenters() {
    var controller = VirtualJoystickController()
    _ = controller.update(displacement: .init(dx: 0, dy: -30), usableRadius: radius)
    XCTAssertEqual(controller.cancel(), [.endMove(.up)])
    XCTAssertEqual(controller.state, VirtualJoystickState())
  }

  func testCancellationWhileIdleEmitsNothing() {
    var controller = VirtualJoystickController()
    XCTAssertEqual(controller.cancel(), [])
    XCTAssertEqual(controller.state, VirtualJoystickState())
  }

  private func direction(_ x: CGFloat, _ y: CGFloat) -> GridDirection? {
    VirtualJoystickController.direction(
      for: CGVector(dx: x, dy: y), usableRadius: radius)
  }
}
