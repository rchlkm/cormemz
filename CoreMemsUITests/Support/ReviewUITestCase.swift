// CoreMemsUITests/Support/ReviewUITestCase.swift
import XCTest

/// Launches the app with in-memory doubles and starts a session, leaving the
/// first photo on screen.
class ReviewUITestCase: XCTestCase {
  static let launchArgument = "-uiTesting"
  static let uiTimeout: TimeInterval = 10

  /// A drag long enough to commit a swipe, and one that stays under the threshold.
  static let committedSwipeDistance: CGFloat = 220
  static let partialSwipeDistance: CGFloat = 60

  var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [Self.launchArgument]
    app.launch()

    let start = app.buttons[AccessibilityID.setupStart]
    XCTAssertTrue(start.waitForExistence(timeout: Self.uiTimeout), "Setup screen never appeared")
    start.tap()
    XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout), "Review screen never appeared")
  }

  func element(_ identifier: String) -> XCUIElement {
    app.descendants(matching: .any)[identifier]
  }

  /// A button by identifier. Prefer this to `element(_:)` where the same identifier can also
  /// land on a button's overlay, as the tray's count badge does.
  func button(_ identifier: String) -> XCUIElement {
    app.buttons[identifier]
  }

  var card: XCUIElement { element(AccessibilityID.reviewCard) }

  func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
    let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))
  }

  func swipeCard(dx: CGFloat = 0, dy: CGFloat = 0) {
    drag(card, dx: dx, dy: dy)
  }

  func waitForProgress(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
    let progress = element(AccessibilityID.reviewProgress)
    let matches = NSPredicate(format: "label == %@", label)
    let result = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: matches, object: progress)],
      timeout: Self.uiTimeout)
    XCTAssertEqual(result, .completed, "Progress never read \"\(label)\"", file: file, line: line)
  }

  /// The number of photos listed in the marked-photos tray.
  func markedPhotoCount() -> Int {
    button(AccessibilityID.reviewTray).tap()
    let closeButton = app.buttons["Close"]
    XCTAssertTrue(closeButton.waitForExistence(timeout: Self.uiTimeout), "Tray never opened")
    let count = app.buttons.matching(identifier: AccessibilityID.trayRestore).count
    closeButton.tap()
    XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout))
    return count
  }
}
