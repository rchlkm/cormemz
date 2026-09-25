// CoreMems/ViewModels/PeekController.swift
import Combine
import Foundation

/// Owns the peek filmstrip's state and the neighbors it has loaded that aren't in the deck.
/// The photos themselves come from `loadNeighbors`.
@MainActor
final class PeekController: ObservableObject {
  /// Returns the photos around `anchorID`: up to `before` older and `after` newer.
  var loadNeighbors: (_ anchorID: String, _ before: Int, _ after: Int) async -> [SessionPhoto] = {
    _, _, _ in []
  }

  /// The neighbors being browsed around the anchor photo; `nil` when not peeking.
  @Published private(set) var state: PeekState?
  @Published private var cache: [String: SessionPhoto] = [:]  // asset ID -> neighbor not in the deck

  var isPeeking: Bool { state != nil }

  /// A peeked photo other than the one peeking started from. Keeping it isn't offered:
  /// it would only mark the photo as reviewed.
  func isNeighbor(_ photoID: String) -> Bool { state.map { $0.anchorID != photoID } ?? false }

  /// Starts browsing the neighbors of `anchorID`, once they load.
  func begin(anchorID: String) {
    guard state == nil else { return }
    state = PeekState(anchorID: anchorID)
    load()
  }

  func end() {
    state = nil
  }

  /// Points the review controls at a peeked neighbor. Reaching the photo at either end of
  /// the strip loads more on that side.
  func focus(on photoID: String) {
    guard let current = state, current.neighborIDs.contains(photoID) else { return }
    state?.focusedID = photoID
    for side in current.edgeSides(of: photoID) { loadMore(side) }
  }

  /// Adds photos to one side of the strip, keeping the focused photo.
  func loadMore(_ side: PeekSide) {
    guard var current = state, current.canLoad(side), !current.isLoading else { return }
    current.widen(side)
    state = current
    load()
  }

  func cachedPhoto(forAssetID assetID: String) -> SessionPhoto? { cache[assetID] }

  func cache(_ photo: SessionPhoto, forAssetID assetID: String) {
    cache[assetID] = photo
  }

  func photo(withID photoID: String) -> SessionPhoto? {
    cache.values.first { $0.id == photoID }
  }

  /// Removes and returns a cached neighbor, for when it joins the deck.
  func take(photoID: String) -> SessionPhoto? {
    guard let key = cache.first(where: { $0.value.id == photoID })?.key else { return nil }
    return cache.removeValue(forKey: key)
  }

  /// Returns whether the photo is a cached neighbor.
  @discardableResult
  func setFavorite(_ isFavorite: Bool, photoID: String) -> Bool {
    guard let key = cache.first(where: { $0.value.id == photoID })?.key else { return false }
    cache[key]?.isFavorite = isFavorite
    return true
  }

  private func load() {
    guard let current = state else { return }
    let (older, newer) = (current.olderCount, current.newerCount)
    Task {
      let neighbors = await loadNeighbors(current.anchorID, older, newer)
      guard state?.anchorID == current.anchorID,
        state?.isCurrentWindow(older: older, newer: newer) == true
      else { return }
      state?.finishLoading(neighborIDs: neighbors.map(\.id))
    }
  }
}
