// CoreMemsUITests/PeekStripTests.swift
import XCTest

final class PeekStripTests: ReviewUITestCase {
  private var peekToggle: XCUIElement { button(AccessibilityID.reviewPeekToggle) }

  func testTogglingPeekSwapsTheControlBarForTheStrip() {
    XCTAssertTrue(button(AccessibilityID.reviewKeep).exists)

    peekToggle.tap()

    XCTAssertTrue(button(AccessibilityID.reviewPeekDelete).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.reviewKeep).exists)

    peekToggle.tap()

    XCTAssertTrue(button(AccessibilityID.reviewKeep).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.reviewPeekDelete).exists)
  }

  func testMarkingFromTheStripFlipsItsButtonToRestoreAndBack() {
    peekToggle.tap()
    button(AccessibilityID.reviewPeekDelete).tap()

    XCTAssertTrue(button(AccessibilityID.reviewPeekRestore).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.reviewPeekDelete).exists)

    button(AccessibilityID.reviewPeekRestore).tap()

    XCTAssertTrue(button(AccessibilityID.reviewPeekDelete).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.reviewPeekRestore).exists)
  }
}
