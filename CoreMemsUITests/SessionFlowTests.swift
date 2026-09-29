// CoreMemsUITests/SessionFlowTests.swift
import XCTest

final class SessionFlowTests: BrowseUITestCase {
  func testMarkedPhotoCanBeRestoredFromTheTray() {
    element(AccessibilityID.browseDelete).tap()
    waitForProgress("1 reviewed")

    button(AccessibilityID.browseTray).tap()
    let restore = app.buttons.matching(identifier: AccessibilityID.trayRestore).firstMatch
    XCTAssertTrue(restore.waitForExistence(timeout: Self.uiTimeout))
    restore.tap()
    app.buttons["Close"].tap()

    XCTAssertEqual(markedPhotoCount(), 0)
  }

  func testMarkedPhotoOpensFullScreenFromTheTrayAndCanBeUndone() {
    element(AccessibilityID.browseDelete).tap()
    waitForProgress("1 reviewed")
    button(AccessibilityID.browseTray).tap()

    element(AccessibilityID.gridPhoto).firstMatch.tap()
    let viewer = element(AccessibilityID.photoViewer)
    XCTAssertTrue(viewer.waitForExistence(timeout: Self.uiTimeout))
    viewer.buttons[AccessibilityID.photoViewerUndo].tap()

    waitForDisappearance(of: viewer)
    XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.trayRestore).count, 0)
  }

  func testClosingTheFullScreenViewerLeavesThePhotoMarked() {
    element(AccessibilityID.browseDelete).tap()
    waitForProgress("1 reviewed")
    button(AccessibilityID.browseTray).tap()

    element(AccessibilityID.gridPhoto).firstMatch.tap()
    let viewer = element(AccessibilityID.photoViewer)
    XCTAssertTrue(viewer.waitForExistence(timeout: Self.uiTimeout))
    viewer.buttons["Close"].tap()

    waitForDisappearance(of: viewer)
    XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.trayRestore).count, 1)
  }

  func testDoneLeadsThroughPendingChangesToCompletion() {
    element(AccessibilityID.browseKeep).tap()
    waitForProgress("1 reviewed")

    element(AccessibilityID.browseDone).tap()
    let confirm = element(AccessibilityID.applyConfirm)
    XCTAssertTrue(confirm.waitForExistence(timeout: Self.uiTimeout))
    confirm.tap()

    XCTAssertTrue(element(AccessibilityID.completion).waitForExistence(timeout: Self.uiTimeout))
  }

  func testEachLaunchStartsClean() {
    element(AccessibilityID.browseKeep).tap()
    waitForProgress("1 reviewed")

    app.terminate()
    app.launch()

    XCTAssertTrue(
      app.buttons[AccessibilityID.setupStart].waitForExistence(timeout: Self.uiTimeout))
  }
}
