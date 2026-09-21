// CoreMemsUITests/PinchGestureTests.swift
import XCTest

final class PinchGestureTests: ReviewUITestCase {
  private static let expandingPinchScale: CGFloat = 2.5
  private static let dismissDragDistance: CGFloat = 300

  func testPinchExpandsTheCardToFullScreen() {
    card.pinch(withScale: Self.expandingPinchScale, velocity: 2)

    XCTAssertTrue(element(AccessibilityID.expandedPhoto).waitForExistence(timeout: Self.uiTimeout))
  }

  func testDraggingDownClosesTheExpandedPhoto() {
    card.pinch(withScale: Self.expandingPinchScale, velocity: 2)
    let expanded = element(AccessibilityID.expandedPhoto)
    XCTAssertTrue(expanded.waitForExistence(timeout: Self.uiTimeout))

    drag(expanded, dx: 0, dy: Self.dismissDragDistance)

    XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(expanded.exists)
  }

  func testTappingTheCardExpandsIt() {
    card.tap()

    XCTAssertTrue(element(AccessibilityID.expandedPhoto).waitForExistence(timeout: Self.uiTimeout))
  }
}
