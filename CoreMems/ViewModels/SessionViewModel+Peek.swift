// CoreMems/ViewModels/SessionViewModel+Peek.swift
import Foundation
import Photos

extension SessionViewModel {
  var isPeeking: Bool { peek != nil }

  /// A peeked photo other than the one peeking started from. Keeping it isn't offered:
  /// it would only mark the photo as reviewed.
  func isPeekedNeighbor(_ photoID: String) -> Bool { peek.map { $0.anchorID != photoID } ?? false }

  /// The photo the review card shows: the one peeking started from, else the active photo.
  var cardPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.anchorID) } ?? currentPhoto }

  /// The photo the review controls act on: the peeked-at neighbor, else the active photo.
  var focusedPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.focusedID) } ?? currentPhoto }

  var peekNeighbors: [SessionPhoto] { (peek?.neighborIDs ?? []).compactMap(photo(withID:)) }

  /// Starts browsing the library neighbors of the active photo, once they load. The review
  /// controls act on the focused neighbor until `endPeek()`.
  func beginPeek() {
    guard peek == nil, let anchor = currentPhoto else { return }
    peek = PeekState(anchorID: anchor.id)
    loadPeekNeighbors()
  }

  /// Leaves peeking; the active photo is the review card's photo again.
  func endPeek() {
    peek = nil
  }

  func togglePeek() {
    if isPeeking { endPeek() } else { beginPeek() }
  }

  /// Points the review controls at a peeked neighbor. Reaching the photo at either end of
  /// the strip loads more on that side.
  func focusPeek(on photoID: String) {
    guard let state = peek, state.neighborIDs.contains(photoID) else { return }
    peek?.focusedID = photoID
    for side in state.edgeSides(of: photoID) { loadMorePeek(side) }
  }

  /// Adds photos to one side of the strip, keeping the focused photo.
  func loadMorePeek(_ side: PeekSide) {
    guard var state = peek, state.canLoad(side), !state.isLoading else { return }
    state.widen(side)
    peek = state
    loadPeekNeighbors()
  }

  private func loadPeekNeighbors() {
    guard let state = peek else { return }
    let (older, newer) = (state.olderCount, state.newerCount)
    Task {
      let neighbors = await neighborPhotos(of: state.anchorID, before: older, after: newer)
      guard peek?.anchorID == state.anchorID, peek?.isCurrentWindow(older: older, newer: newer) == true
      else { return }
      peek?.finishLoading(neighborIDs: neighbors.map(\.id))
    }
  }

  /// Up to `before` older and `after` newer photos around `photoID`'s asset, by the library's own
  /// creation-date order — independent of the session's fetch order. Includes the photo
  /// itself. Neighbors outside the deck stay off it until decided. Empty if the photo
  /// has no real `PHAsset` (mock/preview data).
  func neighborPhotos(of photoID: String, before: Int, after: Int) async -> [SessionPhoto] {
    guard let asset = pickedAssets[photoID] else { return [] }
    let neighbors = await library.neighborAssets(of: asset.localIdentifier, before: before, after: after)
    let deck = Dictionary(photos.map { ($0.assetIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    return neighbors.map { neighbor in
      let id = neighbor.localIdentifier
      if let inDeck = deck[id] { return inDeck }
      if let peeked = peekedPhotos[id] { return peeked }
      let peeked = sessionPhotos(from: [neighbor], startingAt: 0)[0]
      peekedPhotos[id] = peeked
      return peeked
    }
  }
}
