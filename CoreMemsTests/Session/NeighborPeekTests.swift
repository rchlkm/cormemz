// CoreMemsTests/Session/NeighborPeekTests.swift
import Testing

@testable import CoreMems

@Suite("Peek neighbor lookup")
@MainActor
struct NeighborPeekTests {
  @Test func discoversNeighborsNotYetLoadedIntoTheSession() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    // Only the first two lookahead batches (4 photos) are loaded initially.
    #expect(h.vm.photos.count == 4)

    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), radius: 2)

    // Window is library indices 1...5 — indices 4 and 5 weren't loaded into the
    // session yet, so this must reach into the library directly to find them.
    #expect(neighbors.map(\.assetIdentifier) == (1...5).map(SessionHarness.assetID))
    #expect(h.vm.photos.count == 4)
  }

  @Test func reusesAnAlreadyTrackedNeighborRatherThanDuplicatingIt() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let existingID = SessionHarness.photoID(2)

    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), radius: 1)

    let match = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(2) }
    #expect(match?.id == existingID)
    #expect(h.vm.photos.filter { $0.assetIdentifier == SessionHarness.assetID(2) }.count == 1)
  }

  @Test func hasNoNeighborsForAPhotoWithoutARealAsset() async {
    let h = await SessionHarness.started(photoCount: 3)
    let neighbors = await h.vm.neighborPhotos(of: "not-a-real-photo-id", radius: 2)
    #expect(neighbors.isEmpty)
  }

  @Test func decidingOnADiscoveredNeighborByIDMarksItWithoutAdvancingCurrentIndex() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), radius: 2)
    let discovered = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(5) }

    #expect(discovered != nil)
    await h.vm.decide(photoID: discovered!.id, decision: .pendingDelete)?.value

    #expect(h.vm.markedPhotos.contains { $0.id == discovered!.id })
    #expect(h.vm.photos[h.vm.currentIndex].id == SessionHarness.photoID(0))
  }

  @Test func aDecidedNeighborIsNotServedAgainByALaterBatch() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), radius: 2)
    let discovered = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(5) }!
    await h.vm.decide(photoID: discovered.id, decision: .keep)?.value

    for _ in 0..<8 { await h.vm.decide(index: h.vm.currentIndex, decision: .keep)?.value }

    #expect(h.vm.photos.filter { $0.assetIdentifier == SessionHarness.assetID(5) }.count == 1)
  }

  // MARK: Peek session

  private func peeking(photoCount: Int = 10) async -> SessionHarness {
    let h = await SessionHarness.started(photoCount: photoCount, batchSize: 2, mode: .shuffle)
    h.vm.beginPeek()
    while h.vm.isLoadingPeek { await Task.yield() }
    return h
  }

  @Test func peekingLoadsNeighborsAndFocusesTheActivePhoto() async {
    let h = await peeking()

    #expect(h.vm.isPeeking)
    #expect(h.vm.peekNeighbors.map(\.assetIdentifier) == (0...2).map(SessionHarness.assetID))
    #expect(h.vm.focusedPhoto?.id == SessionHarness.photoID(0))
    #expect(h.vm.cardPhoto?.id == SessionHarness.photoID(0))
  }

  @Test func focusingANeighborRedirectsControlsButNotTheCard() async {
    let h = await peeking()

    h.vm.focusPeek(on: SessionHarness.photoID(2))

    #expect(h.vm.focusedPhoto?.id == SessionHarness.photoID(2))
    #expect(h.vm.cardPhoto?.id == SessionHarness.photoID(0))
  }

  @Test func endingPeekReturnsFocusToTheSessionPhoto() async {
    let h = await peeking()
    h.vm.focusPeek(on: SessionHarness.photoID(2))

    h.vm.endPeek()

    #expect(!h.vm.isPeeking)
    #expect(h.vm.focusedPhoto?.id == SessionHarness.photoID(0))
    #expect(h.vm.peekNeighbors.isEmpty)
  }

  @Test func decidingAFocusedNeighborMarksItAndLeavesTheCardInPlace() async {
    let h = await peeking()
    h.vm.focusPeek(on: SessionHarness.photoID(2))

    await h.vm.decide(photoID: SessionHarness.photoID(2), decision: .pendingDelete)?.value

    #expect(h.vm.markedPhotos.map(\.id) == [SessionHarness.photoID(2)])
    #expect(h.vm.cardPhoto?.id == SessionHarness.photoID(0))
    #expect(h.vm.currentPhoto?.id == SessionHarness.photoID(0))
    #expect(h.vm.currentIndex == 1)
    #expect(h.vm.focusedPhoto?.id == SessionHarness.photoID(2))
  }

  @Test func decidingTheSessionPhotoWhilePeekingKeepsTheCardOnIt() async {
    let h = await peeking()

    await h.vm.decide(photoID: SessionHarness.photoID(0), decision: .keep)?.value

    #expect(h.vm.currentPhoto?.id == SessionHarness.photoID(1))
    #expect(h.vm.cardPhoto?.id == SessionHarness.photoID(0))
    #expect(h.vm.cardPhoto?.decision == .keep)
  }

  @Test func favoritingAnUnloadedNeighborLeavesItOutOfTheSession() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .shuffle)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), radius: 2)
    let discovered = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(5) }!

    h.vm.toggleFavorite(photoID: discovered.id)

    #expect(h.vm.photo(withID: discovered.id)?.isFavorite == true)
    #expect(!h.vm.photos.contains { $0.id == discovered.id })
    #expect(h.vm.currentIndex == 0)
  }

  @Test func filingANeighborIntoAnAlbumDoesNotCountItAsReviewed() async {
    let h = await peeking()
    let album = AlbumRef.existing(localIdentifier: "album-1")

    h.vm.toggleAlbumMembership(photoID: SessionHarness.photoID(2), ref: album)

    #expect(h.vm.effectiveAlbums(for: SessionHarness.photoID(2)) == [album])
    #expect(h.vm.currentIndex == 0)
  }

  @Test func aNeighborCannotBeKept() async {
    let h = await peeking()

    let task = h.vm.decide(photoID: SessionHarness.photoID(2), decision: .keep)

    #expect(task == nil)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func undoIsUnavailableWhilePeeking() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .shuffle)
    await h.decide(0, .keep)
    #expect(h.vm.canUndo)

    h.vm.beginPeek()
    while h.vm.isLoadingPeek { await Task.yield() }
    #expect(!h.vm.canUndo)

    h.vm.endPeek()
    #expect(h.vm.canUndo)
  }

  @Test func aNeighborMarkedAheadOfTheDeckIsSkippedWhenReached() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .recent)
    h.vm.beginPeek()
    while h.vm.isLoadingPeek { await Task.yield() }
    await h.vm.decide(photoID: SessionHarness.photoID(1), decision: .pendingDelete)?.value
    h.vm.endPeek()

    await h.decide(h.vm.currentIndex, .keep)

    #expect(h.vm.currentPhoto?.id == SessionHarness.photoID(2))
  }
}
