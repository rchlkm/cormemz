// CoreMemsTests/Session/SessionDeckTests.swift
import Testing

@testable import CoreMems

@Suite("Session deck")
struct SessionDeckTests {
  private func makeDeck(count: Int = 4, liveIndexes: Set<Int> = []) -> SessionDeck {
    SessionDeck(
      photos: (0..<count).map {
        SessionPhoto(
          id: "p\($0)", assetIdentifier: "a\($0)", previewURL: nil, isLivePhoto: liveIndexes.contains($0))
      })
  }

  @Test func decidingTheActivePhotoAdvancesTheCard() {
    var deck = makeDeck()

    let advanced = deck.record(index: 0, decision: .keep)

    #expect(advanced == true)
    #expect(deck.currentIndex == 1)
    #expect(deck.photos[0].decision == .keep)
    #expect(deck.history.count == 1)
  }

  @Test func decidingAnotherPhotoLeavesTheCardWhereItIs() {
    var deck = makeDeck()

    let advanced = deck.record(index: 2, decision: .pendingDelete)

    #expect(advanced == false)
    #expect(deck.currentIndex == 0)
    #expect(deck.pendingItems.map(\.id) == ["p2"])
  }

  @Test func decidingOutsideTheDeckIsIgnored() {
    var deck = makeDeck()

    let ignored = deck.record(index: 9, decision: .keep)
    #expect(ignored == nil)
    #expect(deck.history.isEmpty)
  }

  @Test func onlyLivePhotosAcceptAConversion() {
    let deck = makeDeck(liveIndexes: [1])

    #expect(!deck.accepts(.convertToStill, at: 0))
    #expect(deck.accepts(.convertToStill, at: 1))
    #expect(deck.accepts(.keep, at: 0))
    #expect(!deck.accepts(.keep, at: 9))
  }

  @Test func goBackStepsTheCardBackAndKeepsTheDecision() {
    var deck = makeDeck()
    deck.record(index: 0, decision: .keep)

    let advanced = deck.goBack()

    #expect(advanced == true)
    #expect(deck.currentIndex == 0)
    #expect(deck.photos[0].decision == .keep)
    let nothingToGoBackTo = deck.goBack()
    #expect(nothingToGoBackTo == nil)
  }

  @Test func goingBackOverAnOffCardChangeRestoresThePreviousDecision() {
    var deck = makeDeck()
    deck.record(index: 2, decision: .pendingDelete)

    let advanced = deck.goBack()

    #expect(advanced == false)
    #expect(deck.currentIndex == 0)
    #expect(deck.photos[2].decision == .undecided)
  }

  @Test func adoptingAPhotoAheadMovesItBeforeTheActiveCard() {
    var deck = makeDeck()

    let index = deck.adoptIntoReviewed(photoID: "p3")

    #expect(index == 0)
    #expect(deck.photos.map(\.id) == ["p3", "p0", "p1", "p2"])
    #expect(deck.currentIndex == 1)
    #expect(deck.currentPhoto?.id == "p0")
  }

  @Test func adoptingAnAlreadyReviewedPhotoKeepsItsPlace() {
    var deck = makeDeck()
    deck.record(index: 0, decision: .keep)

    let keptInPlace = deck.adoptIntoReviewed(photoID: "p0")
    #expect(keptInPlace == 0)
    #expect(deck.photos.map(\.id) == ["p0", "p1", "p2", "p3"])
    let missingPhoto = deck.adoptIntoReviewed(photoID: "missing")
    #expect(missingPhoto == nil)
  }

  @Test func insertingAnOutsidePhotoCountsItAsReviewed() {
    var deck = makeDeck()

    let index = deck.insertReviewed(SessionPhoto(id: "peeked", assetIdentifier: "x", previewURL: nil))

    #expect(index == 0)
    #expect(deck.currentIndex == 1)
    #expect(deck.currentPhoto?.id == "p0")
  }

  @Test func restoringMarkedPhotosSetsThemToKeepWithoutMovingTheCard() {
    var deck = makeDeck()
    deck.record(index: 0, decision: .pendingDelete)
    deck.record(index: 1, decision: .keep)

    let restored = deck.restoreMarkedToKeep(ids: ["p0", "p1", "p3"])

    #expect(restored)
    #expect(deck.photos[0].decision == .keep)
    #expect(deck.currentIndex == 2)
    #expect(deck.history.last?.advancedIndex == false)
    let nothingLeft = deck.restoreMarkedToKeep(ids: ["p1"])
    #expect(!nothingLeft)
  }

  @Test func applyingAConversionRepointsThePhotoAtItsStill() {
    var deck = makeDeck(liveIndexes: [1])
    deck.record(index: 1, decision: .convertToStill)

    let converted = deck.applyConversion(photoID: "p1", stillIdentifier: "still")
    #expect(converted)

    #expect(deck.photos[1].assetIdentifier == "still")
    #expect(!deck.photos[1].isLivePhoto)
    #expect(deck.photos[1].decision == .keep)
    let missingConversion = deck.applyConversion(photoID: "missing", stillIdentifier: "still")
    #expect(!missingConversion)
  }

  @Test func favoritesApplyOnlyToDeckPhotos() {
    var deck = makeDeck()

    let favorited = deck.setFavorite(true, photoID: "p2")
    #expect(favorited)
    #expect(deck.photos[2].isFavorite)
    let missingFavorite = deck.setFavorite(true, photoID: "missing")
    #expect(!missingFavorite)
  }

  @Test func remainingCountAndExhaustionFollowTheCard() {
    var deck = makeDeck(count: 2)
    #expect(deck.remainingCount == 2)
    #expect(!deck.isExhausted)

    deck.record(index: 0, decision: .keep)
    deck.record(index: 1, decision: .keep)

    #expect(deck.remainingCount == 0)
    #expect(deck.isExhausted)
    #expect(deck.keptCount == 2)
  }

  @Test func theNextPhotoFollowsTheActiveCard() {
    var deck = makeDeck(count: 2)
    #expect(deck.nextPhoto?.id == "p1")

    deck.record(index: 0, decision: .keep)

    #expect(deck.nextPhoto == nil)
  }

  @Test func keptPhotosLeaveOutConversionsAndDeletions() {
    var deck = makeDeck(liveIndexes: [1])
    deck.record(index: 0, decision: .keep)
    deck.record(index: 1, decision: .convertToStill)
    deck.record(index: 2, decision: .pendingDelete)

    #expect(deck.keptPhotos.map(\.id) == ["p0"])
    #expect(deck.keptCount == 2)
  }

  @Test func photosAreFoundByID() {
    let deck = makeDeck(count: 2)

    #expect(deck.photo(withID: "p1")?.assetIdentifier == "a1")
    #expect(deck.photo(withID: "missing") == nil)
  }

  @Test func appendingAddsPhotosAfterTheExistingOnes() {
    var deck = makeDeck(count: 2)

    deck.append([SessionPhoto(id: "p9", assetIdentifier: "a9", previewURL: nil)])

    #expect(deck.photos.map(\.id) == ["p0", "p1", "p9"])
    #expect(deck.currentIndex == 0)
  }

  @Test func removingPhotosAndClearingHistoryLeavesTheRest() {
    var deck = makeDeck(count: 3)
    deck.record(index: 0, decision: .pendingDelete)

    deck.remove(photoIDs: ["p0"])
    deck.clearHistory()

    #expect(deck.photos.map(\.id) == ["p1", "p2"])
    #expect(deck.history.isEmpty)
  }
}
