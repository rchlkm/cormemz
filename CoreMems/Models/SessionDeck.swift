// CoreMems/Models/SessionDeck.swift
import Foundation

/// The session's photos in review order, the active card, and the step-back history.
struct SessionDeck {
  var photos: [SessionPhoto] = []
  var currentIndex = 0
  var history: [DecisionHistoryEntry] = []

  var currentPhoto: SessionPhoto? { photos.indices.contains(currentIndex) ? photos[currentIndex] : nil }
  var remainingCount: Int { photos.count - currentIndex }
  var isExhausted: Bool { currentIndex >= photos.count }

  var pendingItems: [SessionPhoto] { photos.filter { $0.decision == .pendingDelete } }
  var pendingConversions: [SessionPhoto] { photos.filter { $0.decision == .convertToStill } }
  /// Deletions and conversions together, in the order they were reviewed.
  var markedPhotos: [SessionPhoto] { photos.filter { $0.decision.isMarked } }
  var keptCount: Int { photos.filter { $0.decision.isKept }.count }
  /// Photos decided Keep, not counting conversions.
  var keptPhotos: [SessionPhoto] { photos.filter { $0.decision == .keep } }
  var nextPhoto: SessionPhoto? { photos.indices.contains(currentIndex + 1) ? photos[currentIndex + 1] : nil }

  func index(ofPhotoID photoID: String) -> Int? { photos.firstIndex { $0.id == photoID } }
  func photo(withID photoID: String) -> SessionPhoto? { photos.first { $0.id == photoID } }

  /// Whether a decision can be recorded for the photo at `index`.
  func accepts(_ decision: ReviewDecision, at index: Int) -> Bool {
    photos.indices.contains(index) && photos[index].canReceive(decision)
  }

  /// Records `decision` for the photo at `index` and returns whether it advanced the active
  /// card, or `nil` if there is no photo there.
  @discardableResult
  mutating func record(index: Int, decision: ReviewDecision) -> Bool? {
    guard photos.indices.contains(index) else { return nil }
    let advanced = index == currentIndex
    history.append(
      DecisionHistoryEntry(
        photoIndex: index, previousDecision: photos[index].decision, newDecision: decision,
        advancedIndex: advanced))
    photos[index].decision = decision
    if advanced { currentIndex += 1 }
    return advanced
  }

  /// Steps back one entry and returns whether it had advanced the active card, or `nil` if
  /// there is nothing to step back to. Stepping back onto a photo keeps its decision so it
  /// can be changed on purpose; only a change made off the active card is reverted.
  mutating func goBack() -> Bool? {
    guard let last = history.popLast() else { return nil }
    if last.advancedIndex {
      currentIndex = last.photoIndex
    } else {
      photos[last.photoIndex].decision = last.previousDecision
    }
    return last.advancedIndex
  }

  mutating func append(_ newPhotos: [SessionPhoto]) {
    photos.append(contentsOf: newPhotos)
  }

  /// Removes the photos and keeps the active card on the same photo.
  mutating func remove(photoIDs: Set<String>) {
    let removedBeforeCursor = photos.prefix(currentIndex).filter { photoIDs.contains($0.id) }.count
    photos.removeAll { photoIDs.contains($0.id) }
    currentIndex -= removedBeforeCursor
  }

  mutating func clearHistory() {
    history.removeAll()
  }

  /// Puts a deck photo ahead of the active card into the reviewed part of the deck, leaving
  /// the active card where it is. Returns the photo's index, or `nil` if it isn't in the deck.
  mutating func adoptIntoReviewed(photoID: String) -> Int? {
    guard let index = index(ofPhotoID: photoID) else { return nil }
    guard index > currentIndex else { return index }
    return insertReviewed(photos.remove(at: index))
  }

  /// Adds a photo from outside the deck in front of the active card. Returns its index.
  mutating func insertReviewed(_ photo: SessionPhoto) -> Int {
    photos.insert(photo, at: currentIndex)
    currentIndex += 1
    return currentIndex - 1
  }

  /// Sets marked photos among `ids` back to Keep. Returns whether any changed.
  mutating func restoreMarkedToKeep(ids: Set<String>) -> Bool {
    var restoredAny = false
    for (i, photo) in photos.enumerated() where ids.contains(photo.id) && photo.decision.isMarked {
      history.append(
        DecisionHistoryEntry(
          photoIndex: i, previousDecision: photo.decision, newDecision: .keep, advancedIndex: false))
      photos[i].decision = .keep
      restoredAny = true
    }
    return restoredAny
  }

  /// Returns whether the photo is in the deck.
  @discardableResult
  mutating func setFavorite(_ isFavorite: Bool, photoID: String) -> Bool {
    guard let index = index(ofPhotoID: photoID) else { return false }
    photos[index].isFavorite = isFavorite
    return true
  }

  /// Repoints a converted photo at its still copy as a plain keep. Returns whether it's in the deck.
  mutating func applyConversion(photoID: String, stillIdentifier: String) -> Bool {
    guard let index = index(ofPhotoID: photoID) else { return false }
    photos[index].assetIdentifier = stillIdentifier
    photos[index].isLivePhoto = false
    photos[index].decision = .keep
    return true
  }
}
