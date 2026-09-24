// CoreMems/Models/PeekState.swift
import Foundation

/// Which end of the peek filmstrip: older or newer than the anchor photo.
enum PeekSide {
  case older, newer
}

/// The library neighbors being browsed around one session photo, and which of them the
/// review controls act on.
struct PeekState {
  /// Photos each side starts with, how many an expansion adds, and the most a side can hold.
  static let initialCount = 2
  static let countStep = 2
  static let maxCount = 6
  /// Focusing within this many photos of a strip end loads more on that side.
  static let edgeReach = 2

  let anchorID: String
  var focusedID: String
  var neighborIDs: [String] = []
  private(set) var olderCount = initialCount
  private(set) var newerCount = initialCount
  /// Whether a side can grow: under the cap, and its end of the window was full.
  private(set) var canLoadOlder = false
  private(set) var canLoadNewer = false
  /// The side being added to an already-shown strip.
  private(set) var loadingSide: PeekSide?
  private(set) var isLoading = true

  init(anchorID: String) {
    self.anchorID = anchorID
    focusedID = anchorID
  }

  func canLoad(_ side: PeekSide) -> Bool {
    side == .older ? canLoadOlder : canLoadNewer
  }

  /// The sides of the strip that `photoID` is close enough to the end of to warrant loading.
  func edgeSides(of photoID: String) -> [PeekSide] {
    guard let index = neighborIDs.firstIndex(of: photoID) else { return [] }
    var sides: [PeekSide] = []
    if index < Self.edgeReach { sides.append(.older) }
    if neighborIDs.count - 1 - index < Self.edgeReach { sides.append(.newer) }
    return sides
  }

  /// Grows `side` by one step and marks the strip as loading; the window to fetch is
  /// `olderCount` before and `newerCount` after the anchor.
  mutating func widen(_ side: PeekSide) {
    switch side {
    case .older: olderCount = min(olderCount + Self.countStep, Self.maxCount)
    case .newer: newerCount = min(newerCount + Self.countStep, Self.maxCount)
    }
    canLoadOlder = false
    canLoadNewer = false
    loadingSide = side
    isLoading = true
  }

  /// Whether a load requested for `older` before and `newer` after is still the one wanted.
  func isCurrentWindow(older: Int, newer: Int) -> Bool {
    olderCount == older && newerCount == newer
  }

  /// Takes the fetched window, in library order, and works out which sides can still grow.
  mutating func finishLoading(neighborIDs: [String]) {
    self.neighborIDs = neighborIDs
    let position = neighborIDs.firstIndex(of: anchorID) ?? 0
    canLoadOlder = olderCount < Self.maxCount && position == olderCount
    canLoadNewer = newerCount < Self.maxCount && neighborIDs.count - 1 - position == newerCount
    loadingSide = nil
    isLoading = false
  }
}
