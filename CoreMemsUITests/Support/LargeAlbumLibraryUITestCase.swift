// CoreMemsUITests/Support/LargeAlbumLibraryUITestCase.swift
import XCTest

/// Launches the app against a library of 300 albums and 30 folders and opens Settings.
class LargeAlbumLibraryUITestCase: XCTestCase {
  static let uiTimeout: TimeInterval = 10
  private static let maxScrolls = 10

  var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [ReviewUITestCase.launchArgument, "-uiTestingLargeAlbumLibrary"]
    app.launch()
    let settings = app.buttons["Settings"]
    XCTAssertTrue(settings.waitForExistence(timeout: Self.uiTimeout), "Setup screen never appeared")
    settings.tap()
  }

  /// Opens Settings → Pinned Albums.
  func openPinnedAlbums() {
    app.buttons["Choose albums"].tap()
    XCTAssertTrue(app.navigationBars["Pinned Albums"].waitForExistence(timeout: Self.uiTimeout))
  }

  /// Scrolls until `element` can be tapped; rows outside the visible area don't exist yet.
  func scrollTo(_ element: XCUIElement) {
    var swipes = 0
    while !element.isHittable && swipes < Self.maxScrolls {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(element.isHittable, "\(element) never scrolled into view")
  }
}
