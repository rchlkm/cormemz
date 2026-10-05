// CoreMemsUITests/PinnedAlbumsFlowTests.swift
import XCTest

/// Settings → Pinned Albums against a library where Album 0–5 start pinned and Folder 0 holds
/// Albums 0, 30, 60, 90 and 120.
final class PinnedAlbumsFlowTests: LargeAlbumLibraryUITestCase {
  private func openFolder0() {
    openPinnedAlbums()
    let folder = app.staticTexts["Folder 0"]
    scrollTo(folder)
    folder.tap()
    XCTAssertTrue(app.navigationBars["Folder 0"].waitForExistence(timeout: Self.uiTimeout))
  }

  func testReorderShowsHandlesOnPinnedAlbums() {
    openPinnedAlbums()
    XCTAssertFalse(app.buttons["Reorder Album 0"].exists)

    app.buttons["Reorder"].tap()

    XCTAssertTrue(app.buttons["Reorder Album 0"].waitForExistence(timeout: Self.uiTimeout))
  }

  func testFolderOpensAndListsItsAlbums() {
    openFolder0()

    XCTAssertTrue(app.staticTexts["Album 30"].exists)
    XCTAssertTrue(app.staticTexts["Album 120"].exists)
  }

  func testPinnedAlbumsSortFirstInsideAFolder() {
    openFolder0()
    let unpinned = app.staticTexts["Album 30"]
    let pinning = app.staticTexts["Album 120"]
    XCTAssertLessThan(unpinned.frame.minY, pinning.frame.minY)

    app.buttons["Pin Album 120"].tap()

    XCTAssertTrue(app.buttons["Unpin Album 120"].waitForExistence(timeout: Self.uiTimeout))
    XCTAssertLessThan(pinning.frame.minY, unpinned.frame.minY)
  }

  func testSwipingAnAlbumLeftRevealsUnpinAndRightRevealsDetails() {
    openPinnedAlbums()
    let row = app.staticTexts["Album 0"]

    row.swipeLeft()
    XCTAssertTrue(app.buttons["Unpin"].waitForExistence(timeout: Self.uiTimeout))
    row.tap()

    row.swipeRight()
    XCTAssertTrue(app.buttons["Details"].waitForExistence(timeout: Self.uiTimeout))
  }

  func testSwipingAnAlbumInAFolderRevealsPinAndDetails() {
    openFolder0()
    let row = app.staticTexts["Album 30"]

    row.swipeLeft()
    XCTAssertTrue(app.buttons["Pin"].waitForExistence(timeout: Self.uiTimeout))
    row.tap()

    row.swipeRight()
    XCTAssertTrue(app.buttons["Details"].waitForExistence(timeout: Self.uiTimeout))
  }
}
