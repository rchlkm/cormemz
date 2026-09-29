// CoreMemsTests/Session/ApplyChangesTests.swift
import Photos
import Testing

@testable import CoreMems

@Suite("Applying changes")
@MainActor
struct ApplyChangesTests {
  /// A started session whose browsing is over, so Apply Changes is showing.
  private func finishedSession(
    photoCount: Int, liveIndexes: Set<Int> = [], sizes: [Int: Int64] = [:],
    decisions: [(Int, Decision)]
  ) async -> SessionHarness {
    let h = await SessionHarness.started(
      photoCount: photoCount, liveIndexes: liveIndexes, sizes: sizes)
    for (index, decision) in decisions { await h.decide(index, decision) }
    h.vm.finishEarly()
    return h
  }

  @Test func completionReadsTheLibrarySizeAfterTheCommit() async {
    let h = await finishedSession(photoCount: 3, decisions: [(0, .pendingDelete), (1, .keep)])
    h.library.assets.removeFirst()

    await h.vm.applyChanges()

    #expect(h.vm.eligiblePhotoCount == 2)
  }

  @Test func keepingEverythingCompletesWithoutTouchingTheLibrary() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .keep), (2, .keep)])

    await h.vm.applyChanges()

    #expect(h.library.events.isEmpty)
    #expect(h.vm.screen == .completion)
    #expect(h.haptics.sessionCompleteCallCount == 1)
    #expect(h.stats.stats.totalKept == 3)
    #expect(h.stats.stats.totalDeleted == 0)
    #expect(h.stats.stats.sessionsCompleted == 1)
    #expect(h.persistence.snapshot == nil)
  }

  @Test func keptPhotosAreRememberedAsDecided() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .pendingDelete), (2, .keep)])

    await h.vm.applyChanges()

    #expect(
      h.decidedStore.decidedIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
    #expect(h.vm.decidedPhotoCount == 2)
  }

  @Test func photosHeldForLaterAreNotRememberedAsDecided() async {
    let h = await finishedSession(photoCount: 3, decisions: [(0, .keep), (1, .keep), (2, .keep)])
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(1))

    await h.vm.applyChanges()

    #expect(
      h.decidedStore.decidedIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
  }

  @Test func togglingHeldForLaterTwiceRemembersThePhotoAgain() async {
    let h = await finishedSession(photoCount: 1, decisions: [(0, .keep)])
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(0))
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(0))

    await h.vm.applyChanges()

    #expect(h.decidedStore.decidedIdentifiers() == [SessionHarness.assetID(0)])
  }

  @Test func albumCreatedWithAPhotoIsRecentUntilTheCommitSwapsInTheRealAlbum() async {
    let h = await finishedSession(photoCount: 2, decisions: [(0, .keep), (1, .keep)])
    h.vm.createPendingAlbum(name: "Hikes", assignToPhotoID: SessionHarness.photoID(0))
    let tempID = h.vm.pendingNewAlbums[0].ref.identifier
    #expect(h.vm.recentAlbumIDs.first == tempID)
    h.library.createdAlbumIDs = ["real-album"]

    await h.vm.applyChanges()

    #expect(h.vm.recentAlbumIDs.first == "real-album")
    #expect(!h.vm.recentAlbumIDs.contains(tempID))
  }

  @Test func sizesAreReadBeforeTheSingleCommit() async {
    let h = await finishedSession(
      photoCount: 3, liveIndexes: [2], sizes: [1: 100, 2: 900],
      decisions: [(0, .keep), (1, .pendingDelete), (2, .convertToStill)])

    await h.vm.applyChanges()

    #expect(
      h.library.events == [
        .storageSize([SessionHarness.assetID(1)]),
        .storageSize([SessionHarness.assetID(2)]),
        .apply,
      ])
  }

  @Test func deletionsAndConversionsShareOneCommit() async {
    let h = await finishedSession(
      photoCount: 4, liveIndexes: [1],
      decisions: [(0, .pendingDelete), (1, .convertToStill), (2, .keep), (3, .pendingDelete)])

    await h.vm.applyChanges()

    #expect(h.library.appliedChanges.count == 1)
    let changes = h.library.appliedChanges[0]
    #expect(
      changes.deletions.map(\.localIdentifier)
        == [SessionHarness.assetID(0), SessionHarness.assetID(3)])
    #expect(Set(changes.conversions.keys) == [SessionHarness.photoID(1)])
  }

  @Test func deletionRemovesPhotosRecordsStatsAndClosesTheGoBackWindow() async {
    let h = await finishedSession(
      photoCount: 3, sizes: [1: 100, 2: 250],
      decisions: [(0, .keep), (1, .pendingDelete), (2, .pendingDelete)])

    await h.vm.applyChanges()

    #expect(h.vm.screen == .completion)
    #expect(h.vm.deletedCount == 2)
    #expect(h.vm.photos.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.canGoBack == false)
    #expect(h.vm.isDeleting == false)
    #expect(h.vm.deletionError == nil)
    #expect(h.stats.stats.totalDeleted == 2)
    #expect(h.stats.stats.totalKept == 1)
    #expect(h.stats.stats.bytesDeleted == 350)
    #expect(h.vm.deletedBytes == 350)
    #expect(h.persistence.snapshot == nil)
  }

  @Test func conversionBecomesAPlainKeepOfTheStillCopy() async {
    let h = await finishedSession(
      photoCount: 2, liveIndexes: [1], sizes: [1: 900],
      decisions: [(0, .keep), (1, .convertToStill)])

    await h.vm.applyChanges()

    let converted = h.vm.photos[1]
    #expect(converted.decision == .keep)
    #expect(converted.isLivePhoto == false)
    #expect(converted.assetIdentifier == "still-\(SessionHarness.assetID(1))")
    #expect(h.vm.convertedLivePhotoCount == 1)
    #expect(h.stats.stats.livePhotosConverted == 1)
    #expect(h.vm.pendingConversions.isEmpty)
    #expect(h.vm.screen == .completion)
    #expect(h.vm.deletedCount == 0)
  }

  @Test func conversionRecordsOriginalSizeMinusStillSize() async {
    let h = await finishedSession(
      photoCount: 2, liveIndexes: [1], sizes: [1: 900],
      decisions: [(0, .keep), (1, .convertToStill)])
    h.library.stillSizes = [SessionHarness.assetID(1): 300]

    await h.vm.applyChanges()

    #expect(h.stats.stats.bytesSavedByConversion == 600)
    #expect(h.vm.convertedBytesSaved == 600)
  }

  @Test func rejectedCommitLeavesTheSessionUntouched() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .pendingDelete), (2, .keep)])
    h.library.applyFailure = LibraryTestError.rejected

    await h.vm.applyChanges()

    #expect(h.vm.deletionError != nil)
    #expect(h.vm.screen == .pendingChanges)
    #expect(h.vm.photos.count == 3)
    #expect(h.vm.photos[1].decision == .pendingDelete)
    #expect(h.vm.canGoBack)
    #expect(h.vm.isDeleting == false)
    #expect(h.haptics.sessionCompleteCallCount == 0)
    #expect(h.stats.stats.sessionsCompleted == 0)
    #expect(h.persistence.snapshot != nil)
  }

  @Test func decliningTheSystemPromptKeepsTheSessionOpenWithoutAnError() async {
    let h = await finishedSession(
      photoCount: 2, decisions: [(0, .pendingDelete), (1, .keep)])
    h.library.applyFailure = PHPhotosError(.userCancelled)

    await h.vm.applyChanges()

    #expect(h.vm.deletionError == nil)
    #expect(h.vm.screen == .pendingChanges)
    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.stats.stats.sessionsCompleted == 0)
  }

  @Test func aMissingStillCopyReportsAnErrorAndStaysOnPendingChanges() async {
    let h = await finishedSession(
      photoCount: 3, liveIndexes: [1, 2],
      decisions: [(0, .keep), (1, .convertToStill), (2, .convertToStill)])
    h.library.photoIDsWithoutStill = [SessionHarness.photoID(2)]

    await h.vm.applyChanges()

    #expect(h.vm.deletionError == PhotoLibraryError.creationFailed.localizedDescription)
    #expect(h.vm.screen == .pendingChanges)
    #expect(h.vm.photos[1].decision == .keep)
    #expect(h.vm.photos[1].isLivePhoto == false)
    #expect(h.vm.photos[2].decision == .convertToStill)
    #expect(h.vm.convertedLivePhotoCount == 1)
    #expect(h.stats.stats.sessionsCompleted == 0)
  }
}
