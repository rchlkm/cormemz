// CoreMemsUITests/EditFlowTests.swift
import XCTest

final class EditFlowTests: BrowseUITestCase {
  private func openEditor() {
    card.tap()
    let edit = button(AccessibilityID.editStart)
    XCTAssertTrue(edit.waitForExistence(timeout: Self.uiTimeout))
    edit.tap()
    XCTAssertTrue(button(AccessibilityID.editRotate).waitForExistence(timeout: Self.uiTimeout))
  }

  func testDoneIsUnavailableUntilSomethingChanges() {
    openEditor()

    XCTAssertFalse(button(AccessibilityID.editDone).isEnabled)
    button(AccessibilityID.editRotate).tap()
    XCTAssertTrue(button(AccessibilityID.editDone).isEnabled)
  }

  func testSavingAnEditReturnsToTheSameUndecidedCard() {
    openEditor()
    button(AccessibilityID.editRotate).tap()
    button(AccessibilityID.editDone).tap()

    waitForDisappearance(of: element(AccessibilityID.expandedPhoto))
    waitForProgress("0 reviewed")
    XCTAssertTrue(app.staticTexts["Edited"].waitForExistence(timeout: Self.uiTimeout))
  }

  func testAnEditIsListedForApplyAlongsideTheKeep() {
    openEditor()
    button(AccessibilityID.editRotate).tap()
    button(AccessibilityID.editDone).tap()
    waitForDisappearance(of: element(AccessibilityID.expandedPhoto))

    element(AccessibilityID.browseKeep).tap()
    waitForProgress("1 reviewed")
    element(AccessibilityID.browseDone).tap()
    XCTAssertTrue(app.staticTexts["1 edited"].waitForExistence(timeout: Self.uiTimeout))
  }

  func testUndoingAnEditFromTheTrayRemovesIt() {
    openEditor()
    button(AccessibilityID.editRotate).tap()
    button(AccessibilityID.editDone).tap()
    waitForDisappearance(of: element(AccessibilityID.expandedPhoto))

    button(AccessibilityID.browseTray).tap()
    let restore = button(AccessibilityID.trayRestore)
    XCTAssertTrue(restore.waitForExistence(timeout: Self.uiTimeout))
    restore.tap()
    waitForDisappearance(of: restore)
  }

  func testPhotoEditorShowsToolBarWithOnlyWorkingControlsEnabled() {
    openEditor()

    XCTAssertTrue(app.buttons["Crop"].exists)
    XCTAssertTrue(button(AccessibilityID.editRotate).isEnabled)
    XCTAssertFalse(app.buttons["Flip"].isEnabled)
    XCTAssertFalse(app.buttons["Aspect ratio"].isEnabled)
  }

  func testCancellingLeavesThePhotoUndecided() {
    openEditor()
    button(AccessibilityID.editRotate).tap()
    button(AccessibilityID.editCancel).tap()

    XCTAssertTrue(button(AccessibilityID.editStart).waitForExistence(timeout: Self.uiTimeout))
    waitForProgress("0 reviewed")
  }
}
