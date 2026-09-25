// CoreMemsTests/Session/SessionConfirmationPlanTests.swift
import Photos
import Testing

@testable import CoreMems

@Suite("Session confirmation plan")
struct SessionConfirmationPlanTests {
  private func makeDeck(_ decisions: [ReviewDecision], live: Set<Int> = []) -> SessionDeck {
    SessionDeck(
      photos: decisions.enumerated().map { index, decision in
        var photo = SessionPhoto(
          id: "p\(index)", assetIdentifier: "a\(index)", previewURL: nil,
          isLivePhoto: live.contains(index))
        photo.decision = decision
        return photo
      })
  }

  private func assets(for deck: SessionDeck) -> [String: PHAsset] {
    Dictionary(
      uniqueKeysWithValues: deck.photos.map {
        ($0.id, FakeAsset(identifier: $0.assetIdentifier, isLive: $0.isLivePhoto))
      })
  }

  @Test func nothingMarkedPlansNoChanges() {
    let deck = makeDeck([.keep, .keep])

    let plan = SessionConfirmationPlan(deck: deck, assets: assets(for: deck), staging: AlbumStaging())

    #expect(plan.changes.isEmpty)
    #expect(plan.deletions.isEmpty)
    #expect(plan.keptCount == 2)
  }

  @Test func markedPhotosBecomeDeletionsAndConversions() {
    let deck = makeDeck([.pendingDelete, .convertToStill, .keep], live: [1])
    let library = assets(for: deck)

    let plan = SessionConfirmationPlan(deck: deck, assets: library, staging: AlbumStaging())

    #expect(plan.deletions.map(\.id) == ["p0"])
    #expect(plan.changes.deletions.map(\.localIdentifier) == ["a0"])
    #expect(plan.conversions.map(\.id) == ["p1"])
    #expect(Array(plan.changes.conversions.keys) == ["p1"])
    #expect(plan.keptCount == 2)
  }

  @Test func aConversionWithoutItsAssetIsLeftOut() {
    let deck = makeDeck([.convertToStill], live: [0])

    let plan = SessionConfirmationPlan(deck: deck, assets: [:], staging: AlbumStaging())

    #expect(plan.conversions.isEmpty)
    #expect(plan.changes.conversions.isEmpty)
  }

  @Test func albumChangesOnDeletedPhotosAreDropped() {
    let deck = makeDeck([.pendingDelete, .keep])
    var staging = AlbumStaging()
    let ref = AlbumRef.existing(localIdentifier: "album")
    _ = staging.toggle(photoID: "p0", ref: ref)
    _ = staging.toggle(photoID: "p1", ref: ref)

    let plan = SessionConfirmationPlan(deck: deck, assets: assets(for: deck), staging: staging)

    #expect(Array(plan.changes.albumAdditions.keys) == ["p1"])
  }
}
