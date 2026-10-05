// CoreMemsUITests/ConversionFlowTests.swift
import XCTest

/// The mock library makes every fifth photo a Live Photo, starting with the third.
final class ConversionFlowTests: BrowseUITestCase {
  private static let firstLivePhotoPosition = 2
  private static let convertMenuItem = "Convert to Still Photo"
  private static let conversionFilter = "Convert 1"
 
  private func reachFirstLivePhoto() {
    XCTAssertFalse(element(AccessibilityID.liveBadge).exists)
    for reviewed in 1...Self.firstLivePhotoPosition {
      element(AccessibilityID.browseKeep).tap()
      waitForProgress("\(reviewed) reviewed")
    }
    XCTAssertTrue(element(AccessibilityID.liveBadge).waitForExistence(timeout: Self.uiTimeout))
  }

  private func convertCurrentPhoto() {
    element(AccessibilityID.liveBadge).press(forDuration: 1)
    let menuItem = app.buttons[Self.convertMenuItem]
    XCTAssertTrue(menuItem.waitForExistence(timeout: Self.uiTimeout))
    menuItem.tap()
    waitForProgress("\(Self.firstLivePhotoPosition + 1) reviewed")
  }

  /// Converts the first Live Photo, deletes the next photo, and opens the final browse.
  private func openFinalBrowseWithOneOfEach() {
    reachFirstLivePhoto()
    convertCurrentPhoto()
    element(AccessibilityID.browseDelete).tap()
    waitForProgress("\(Self.firstLivePhotoPosition + 2) reviewed")
    element(AccessibilityID.browseDone).tap()
    XCTAssertTrue(
      element(AccessibilityID.applyConfirm).waitForExistence(timeout: Self.uiTimeout))
  }

  func testSwipingTheFinalBrowseMovesBetweenFilters() {
    openFinalBrowseWithOneOfEach()
    let filters = app.segmentedControls.firstMatch
    waitUntilSelected(filters.buttons["All 2"])

    app.swipeLeft()
    waitUntilSelected(filters.buttons["Delete 1"])

    app.swipeLeft()
    waitUntilSelected(filters.buttons["Convert 1"])
  }

  func testUndoingFromFullScreenInTheFinalBrowseDropsThatPhoto() {
    openFinalBrowseWithOneOfEach()
    app.segmentedControls.firstMatch.buttons["Delete 1"].tap()

    element(AccessibilityID.gridPhoto).firstMatch.tap()
    let viewer = element(AccessibilityID.photoViewer)
    XCTAssertTrue(viewer.waitForExistence(timeout: Self.uiTimeout))
    viewer.buttons[AccessibilityID.photoViewerUndo].tap()

    XCTAssertTrue(app.segmentedControls.firstMatch.buttons[Self.conversionFilter].waitForExistence(timeout: Self.uiTimeout))
  }

  func testConvertingALivePhotoMarksItInTheTray() {
    reachFirstLivePhoto()

    convertCurrentPhoto()

    XCTAssertEqual(markedPhotoCount(), 1)
  }

  func testConversionIsListedOnPendingChangesAndCompletesTheSession() {
    reachFirstLivePhoto()
    convertCurrentPhoto()

    element(AccessibilityID.browseDone).tap()

    XCTAssertTrue(app.segmentedControls.firstMatch.buttons[Self.conversionFilter].waitForExistence(timeout: Self.uiTimeout))
    element(AccessibilityID.applyConfirm).tap()
    XCTAssertTrue(element(AccessibilityID.completion).waitForExistence(timeout: Self.uiTimeout))
  }

  func testGoBackKeepsTheConversionMarked() {
    reachFirstLivePhoto()
    convertCurrentPhoto()

    element(AccessibilityID.browseGoBack).tap()

    waitForProgress("\(Self.firstLivePhotoPosition) reviewed")
    XCTAssertEqual(markedPhotoCount(), 1)
  }
}
