// CoreMemsUITests/SessionFlowTests.swift
import XCTest

final class SessionFlowTests: ReviewUITestCase {
  func testMarkedPhotoCanBeRestoredFromTheTray() {
    element(AccessibilityID.reviewDelete).tap()
    waitForProgress("1 reviewed")

    button(AccessibilityID.reviewTray).tap()
    let restore = app.buttons.matching(identifier: AccessibilityID.trayRestore).firstMatch
    XCTAssertTrue(restore.waitForExistence(timeout: Self.uiTimeout))
    restore.tap()
    app.buttons["Close"].tap()

    XCTAssertEqual(markedPhotoCount(), 0)
  }

  func testDoneLeadsThroughPendingReviewToCompletion() {
    element(AccessibilityID.reviewKeep).tap()
    waitForProgress("1 reviewed")

    element(AccessibilityID.reviewDone).tap()
    let confirm = element(AccessibilityID.pendingConfirm)
    XCTAssertTrue(confirm.waitForExistence(timeout: Self.uiTimeout))
    confirm.tap()

    XCTAssertTrue(element(AccessibilityID.completion).waitForExistence(timeout: Self.uiTimeout))
  }

  func testEachLaunchStartsClean() {
    element(AccessibilityID.reviewKeep).tap()
    waitForProgress("1 reviewed")

    app.terminate()
    app.launch()

    XCTAssertTrue(
      app.buttons[AccessibilityID.setupStart].waitForExistence(timeout: Self.uiTimeout))
  }
}
