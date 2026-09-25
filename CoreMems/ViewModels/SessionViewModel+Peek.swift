// CoreMems/ViewModels/SessionViewModel+Peek.swift
import Foundation

extension SessionViewModel {
  /// The library neighbors being browsed around the session photo; `nil` when not peeking.
  var peek: PeekState? { peekController.state }
  var isPeeking: Bool { peekController.isPeeking }

  func isPeekedNeighbor(_ photoID: String) -> Bool { peekController.isNeighbor(photoID) }

  /// The photo the review card shows: the one peeking started from, else the active photo.
  var cardPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.anchorID) } ?? currentPhoto }

  /// The photo the review controls act on: the peeked-at neighbor, else the active photo.
  var focusedPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.focusedID) } ?? currentPhoto }

  var peekNeighbors: [SessionPhoto] { (peek?.neighborIDs ?? []).compactMap(photo(withID:)) }

  /// Starts browsing the library neighbors of the active photo, once they load. The review
  /// controls act on the focused neighbor until `endPeek()`.
  func beginPeek() {
    guard let anchor = currentPhoto else { return }
    peekController.begin(anchorID: anchor.id)
  }

  /// Leaves peeking; the active photo is the review card's photo again.
  func endPeek() {
    peekController.end()
  }

  func togglePeek() {
    if isPeeking { endPeek() } else { beginPeek() }
  }

  func focusPeek(on photoID: String) {
    peekController.focus(on: photoID)
  }

  func loadMorePeek(_ side: PeekSide) {
    peekController.loadMore(side)
  }
}
