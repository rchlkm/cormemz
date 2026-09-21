// CoreMemsUITests/SwipeGestureTests.swift
import XCTest

final class SwipeGestureTests: ReviewUITestCase {
  /// How far a drag must move the card to count as followed; the last reported point lags the finger.
  private static let minimumFollowedDistance: CGFloat = 10

  func testSwipeRightKeepsThePhoto() {
    swipeCard(dx: Self.committedSwipeDistance)

    waitForProgress("1 reviewed")
    XCTAssertEqual(markedPhotoCount(), 0)
  }

  func testSwipeDownMarksThePhotoForDeletion() {
    swipeCard(dy: Self.committedSwipeDistance)

    waitForProgress("1 reviewed")
    XCTAssertEqual(markedPhotoCount(), 1)
  }

  func testShortDragDoesNotDecide() {
    swipeCard(dx: Self.partialSwipeDistance)

    XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout))
    waitForProgress("0 reviewed")
  }

  func testCardFollowsTheFingerDuringADrag() {
    swipeCard(dx: Self.partialSwipeDistance)

    let translation = dragTranslation()
    XCTAssertGreaterThan(translation.width, Self.minimumFollowedDistance)
    XCTAssertLessThan(abs(translation.height), translation.width / 2)
  }

  func testUndoIsDisabledUntilThereIsSomethingToUndo() {
    XCTAssertFalse(element(AccessibilityID.reviewUndo).isEnabled)

    element(AccessibilityID.reviewKeep).tap()
    waitForProgress("1 reviewed")

    XCTAssertTrue(element(AccessibilityID.reviewUndo).isEnabled)
  }

  func testUndoButtonBringsBackThePreviousPhoto() {
    element(AccessibilityID.reviewDelete).tap()
    waitForProgress("1 reviewed")

    element(AccessibilityID.reviewUndo).tap()

    waitForProgress("0 reviewed")
    XCTAssertEqual(markedPhotoCount(), 0)
  }

  func testSwipeLeftUndoesTheLastDecision() {
    element(AccessibilityID.reviewKeep).tap()
    waitForProgress("1 reviewed")

    swipeCard(dx: -Self.committedSwipeDistance)

    waitForProgress("0 reviewed")
  }

  /// The card's last drag translation, exposed as the card's accessibility value ("x,y").
  private func dragTranslation() -> CGSize {
    let moved = NSPredicate(format: "value != %@", "0,0")
    let result = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: moved, object: card)],
      timeout: Self.uiTimeout)
    XCTAssertEqual(result, .completed, "The card never reported a drag")

    let parts = (card.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
    guard parts.count == 2 else {
      XCTFail("Unexpected drag value: \(String(describing: card.value))")
      return .zero
    }
    return CGSize(width: parts[0], height: parts[1])
  }
}
