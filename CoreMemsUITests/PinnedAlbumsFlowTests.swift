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

  func testPinnedAlbumsShowReorderHandles() {
    openPinnedAlbums()

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
}
