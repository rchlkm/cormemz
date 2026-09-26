// CoreMemsUITests/PinnedAlbumsPerformanceTests.swift
import XCTest

/// Opens Settings → Pinned Albums against a library of 300 albums and 30 folders.
final class PinnedAlbumsPerformanceTests: LargeAlbumLibraryUITestCase {
  private static let iterations = 5

  func testOpeningPinnedAlbumsHasNoHitches() {
    let options = XCTMeasureOptions()
    options.iterationCount = Self.iterations
    let pinnedAlbumsBar = app.navigationBars["Pinned Albums"]
    measure(metrics: [XCTHitchMetric(application: app)], options: options) {
      app.buttons["Choose albums"].tap()
      XCTAssertTrue(pinnedAlbumsBar.waitForExistence(timeout: Self.uiTimeout))
      pinnedAlbumsBar.buttons.firstMatch.tap()
    }
  }
}
