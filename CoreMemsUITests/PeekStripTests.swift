// CoreMemsUITests/PeekStripTests.swift
import XCTest

final class PeekStripTests: BrowseUITestCase {
  private var peekToggle: XCUIElement { button(AccessibilityID.browsePeekToggle) }

  func testTogglingPeekSwapsTheControlBarForTheStrip() {
    XCTAssertTrue(button(AccessibilityID.browseKeep).exists)

    peekToggle.tap()

    XCTAssertTrue(button(AccessibilityID.browsePeekDelete).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.browseKeep).exists)

    peekToggle.tap()

    XCTAssertTrue(button(AccessibilityID.browseKeep).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.browsePeekDelete).exists)
  }

  func testMarkingFromTheStripFlipsItsButtonToRestoreAndBack() {
    peekToggle.tap()
    button(AccessibilityID.browsePeekDelete).tap()

    XCTAssertTrue(button(AccessibilityID.browsePeekRestore).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.browsePeekDelete).exists)

    button(AccessibilityID.browsePeekRestore).tap()

    XCTAssertTrue(button(AccessibilityID.browsePeekDelete).waitForExistence(timeout: Self.uiTimeout))
    XCTAssertFalse(button(AccessibilityID.browsePeekRestore).exists)
  }
}
