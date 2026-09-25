// CoreMemsTests/Session/PeekSessionTests.swift
import Testing

@testable import CoreMems

@Suite("Peek session")
@MainActor
struct PeekSessionTests {
  private func settle(_ vm: SessionViewModel) async {
    while vm.peek?.isLoading == true { await Task.yield() }
  }

  /// A session whose active photo is library index 0, so the strip holds indexes 0...2.
  private func peeking(photoCount: Int = 10) async -> SessionHarness {
    let h = await SessionHarness.started(photoCount: photoCount, batchSize: 2, mode: .shuffle)
    h.vm.beginPeek()
    await settle(h.vm)
    return h
  }

  /// A session whose active photo is library index 3, so the strip holds indexes 1...5.
  private func peekingMidLibrary() async -> SessionHarness {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .shuffle)
    for index in 0..<3 { await h.decide(index, .keep) }
    h.vm.beginPeek()
    await settle(h.vm)
    return h
  }

  // MARK: Focus and decisions

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

  @Test func aNeighborMarkedForDeletionCanBeRestored() async {
    let h = await peeking()
    await h.vm.decide(photoID: SessionHarness.photoID(2), decision: .pendingDelete)?.value
    #expect(h.vm.markedPhotos.count == 1)

    h.vm.restoreMany(ids: [SessionHarness.photoID(2)])

    #expect(h.vm.markedPhotos.isEmpty)
    #expect(h.vm.photo(withID: SessionHarness.photoID(2))?.decision == .keep)
    #expect(h.vm.cardPhoto?.id == SessionHarness.photoID(0))
  }

  @Test func aNeighborCannotBeKept() async {
    let h = await peeking()

    let task = h.vm.decide(photoID: SessionHarness.photoID(2), decision: .keep)

    #expect(task == nil)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func aNeighborMarkedAheadOfTheDeckIsSkippedWhenReached() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .recent)
    h.vm.beginPeek()
    await settle(h.vm)
    await h.vm.decide(photoID: SessionHarness.photoID(1), decision: .pendingDelete)?.value
    h.vm.endPeek()

    await h.decide(h.vm.currentIndex, .keep)

    #expect(h.vm.currentPhoto?.id == SessionHarness.photoID(2))
  }

  @Test func goBackIsUnavailableWhilePeeking() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .shuffle)
    await h.decide(0, .keep)
    #expect(h.vm.canGoBack)

    h.vm.beginPeek()
    await settle(h.vm)
    #expect(!h.vm.canGoBack)

    h.vm.endPeek()
    #expect(h.vm.canGoBack)
  }

  // MARK: Favorites and albums

  @Test func favoritingAnUnloadedNeighborLeavesItOutOfTheSession() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2, mode: .shuffle)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), before: 2, after: 2)
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

  // MARK: Growing the strip

  @Test func loadingOlderWidensOnlyTheOlderSide() async {
    let h = await peekingMidLibrary()
    #expect(h.vm.peek?.canLoadOlder == true)

    h.vm.loadMorePeek(.older)
    await settle(h.vm)

    #expect(h.vm.peek?.olderCount == 4)
    #expect(h.vm.peek?.newerCount == 2)
    #expect(h.vm.peekNeighbors.map(\.assetIdentifier) == (0...5).map(SessionHarness.assetID))
    #expect(h.vm.peek?.canLoadOlder == false)
  }

  @Test func loadingNewerWidensOnlyTheNewerSideAndKeepsTheFocusedPhoto() async {
    let h = await peekingMidLibrary()
    let focused = SessionHarness.photoID(3)
    h.vm.focusPeek(on: focused)

    h.vm.loadMorePeek(.newer)
    await settle(h.vm)

    #expect(h.vm.peek?.newerCount == 4)
    #expect(h.vm.peek?.olderCount == 2)
    #expect(h.vm.peekNeighbors.map(\.assetIdentifier) == (1...7).map(SessionHarness.assetID))
    #expect(h.vm.focusedPhoto?.id == focused)
  }

  @Test func scrollingToTheNewestPhotoLoadsNewerPhotos() async {
    let h = await peekingMidLibrary()

    h.vm.focusPeek(on: h.vm.peek!.neighborIDs.last!)
    await settle(h.vm)

    #expect(h.vm.peek?.newerCount == 4)
    #expect(h.vm.peek?.olderCount == 2)
  }

  @Test func scrollingToTheOldestPhotoLoadsOlderPhotos() async {
    let h = await peekingMidLibrary()

    h.vm.focusPeek(on: h.vm.peek!.neighborIDs.first!)
    await settle(h.vm)

    #expect(h.vm.peek?.olderCount == 4)
    #expect(h.vm.peek?.newerCount == 2)
  }

  @Test func focusingAPhotoNextToTheEndAlsoLoadsMore() async {
    let h = await peekingMidLibrary()

    h.vm.focusPeek(on: h.vm.peek!.neighborIDs[3])

    #expect(h.vm.peek?.loadingSide == .newer)
    await settle(h.vm)
    #expect(h.vm.peek?.loadingSide == nil)
    #expect(h.vm.peek?.newerCount == 4)
  }

  @Test func focusingTheMiddleOfTheStripLoadsNothing() async {
    let h = await peekingMidLibrary()

    h.vm.focusPeek(on: SessionHarness.photoID(3))

    #expect(h.vm.peek?.isLoading == false)
    #expect(h.vm.peek?.olderCount == 2)
    #expect(h.vm.peek?.newerCount == 2)
  }

  @Test func aSideAtTheLibraryStartCannotLoadMore() async {
    let h = await peeking()
    #expect(h.vm.peek?.canLoadOlder == false)

    h.vm.loadMorePeek(.older)

    #expect(h.vm.peek?.isLoading == false)
    #expect(h.vm.peek?.olderCount == 2)
  }

  @Test func aSideStopsLoadingAtTheCap() async {
    let h = await SessionHarness.started(photoCount: 30, batchSize: 2, mode: .shuffle)
    h.vm.beginPeek()
    await settle(h.vm)
    while h.vm.peek?.canLoadNewer == true {
      h.vm.loadMorePeek(.newer)
      await settle(h.vm)
    }

    #expect(h.vm.peek?.newerCount == 6)
    #expect(h.vm.peekNeighbors.count == 7)
  }

  @Test func peekingAgainStartsAtTheInitialStripSize() async {
    let h = await peekingMidLibrary()
    h.vm.loadMorePeek(.newer)
    await settle(h.vm)

    h.vm.endPeek()
    h.vm.beginPeek()

    #expect(h.vm.peek?.newerCount == 2)
    #expect(h.vm.peek?.canLoadNewer == false)
  }
}
