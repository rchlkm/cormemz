// CoreMemsUITests/ConversionFlowTests.swift
import XCTest

/// The mock library makes every fifth photo a Live Photo, starting with the third.
final class ConversionFlowTests: ReviewUITestCase {
  private static let firstLivePhotoPosition = 2
  private static let convertMenuItem = "Convert to Still Photo"
  private static let conversionSummary = "1 Live Photo will become a still photo"
 
  private func reachFirstLivePhoto() {
    XCTAssertFalse(element(AccessibilityID.liveBadge).exists)
    for reviewed in 1...Self.firstLivePhotoPosition {
      element(AccessibilityID.reviewKeep).tap()
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

  func testConvertingALivePhotoMarksItInTheTray() {
    reachFirstLivePhoto()

    convertCurrentPhoto()

    XCTAssertEqual(markedPhotoCount(), 1)
  }

  func testConversionIsListedOnPendingReviewAndCompletesTheSession() {
    reachFirstLivePhoto()
    convertCurrentPhoto()

    element(AccessibilityID.reviewDone).tap()

    XCTAssertTrue(app.staticTexts[Self.conversionSummary].waitForExistence(timeout: Self.uiTimeout))
    element(AccessibilityID.pendingConfirm).tap()
    XCTAssertTrue(element(AccessibilityID.completion).waitForExistence(timeout: Self.uiTimeout))
  }

  func testUndoRevertsAConversion() {
    reachFirstLivePhoto()
    convertCurrentPhoto()

    element(AccessibilityID.reviewUndo).tap()

    waitForProgress("\(Self.firstLivePhotoPosition) reviewed")
    XCTAssertEqual(markedPhotoCount(), 0)
  }
}
