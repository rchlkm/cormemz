// CoreMemsTests/Session/ConfirmTests.swift
import Photos
import Testing

@testable import CoreMems

@Suite("Confirming a session")
@MainActor
struct ConfirmTests {
  /// A started session whose review is over, so Pending Review is showing.
  private func finishedSession(
    photoCount: Int, liveIndexes: Set<Int> = [], sizes: [Int: Int64] = [:],
    decisions: [(Int, ReviewDecision)]
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

    await h.vm.confirmSession()

    #expect(h.vm.eligiblePhotoCount == 2)
  }

  @Test func keepingEverythingCompletesWithoutTouchingTheLibrary() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .keep), (2, .keep)])

    await h.vm.confirmSession()

    #expect(h.library.events.isEmpty)
    #expect(h.vm.screen == .completion)
    #expect(h.haptics.sessionCompleteCallCount == 1)
    #expect(h.stats.stats.totalKept == 3)
    #expect(h.stats.stats.totalDeleted == 0)
    #expect(h.stats.stats.sessionsCompleted == 1)
    #expect(h.persistence.snapshot == nil)
  }

  @Test func keptPhotosAreRememberedAsReviewed() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .pendingDelete), (2, .keep)])

    await h.vm.confirmSession()

    #expect(
      h.reviewedStore.reviewedIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
    #expect(h.vm.reviewedPhotoCount == 2)
  }

  @Test func sizesAreReadBeforeTheSingleCommit() async {
    let h = await finishedSession(
      photoCount: 3, liveIndexes: [2], sizes: [1: 100, 2: 900],
      decisions: [(0, .keep), (1, .pendingDelete), (2, .convertToStill)])

    await h.vm.confirmSession()

    #expect(
      h.library.events == [
        .storageSize([SessionHarness.assetID(1)]),
        .storageSize([SessionHarness.assetID(2)]),
        .commit,
      ])
  }

  @Test func deletionsAndConversionsShareOneCommit() async {
    let h = await finishedSession(
      photoCount: 4, liveIndexes: [1],
      decisions: [(0, .pendingDelete), (1, .convertToStill), (2, .keep), (3, .pendingDelete)])

    await h.vm.confirmSession()

    #expect(h.library.committedChanges.count == 1)
    let changes = h.library.committedChanges[0]
    #expect(
      changes.deletions.map(\.localIdentifier)
        == [SessionHarness.assetID(0), SessionHarness.assetID(3)])
    #expect(Set(changes.conversions.keys) == [SessionHarness.photoID(1)])
  }

  @Test func deletionRemovesPhotosRecordsStatsAndClosesTheGoBackWindow() async {
    let h = await finishedSession(
      photoCount: 3, sizes: [1: 100, 2: 250],
      decisions: [(0, .keep), (1, .pendingDelete), (2, .pendingDelete)])

    await h.vm.confirmSession()

    #expect(h.vm.screen == .completion)
    #expect(h.vm.deletedCount == 2)
    #expect(h.vm.photos.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.canGoBack == false)
    #expect(h.vm.isDeleting == false)
    #expect(h.vm.deletionError == nil)
    #expect(h.stats.stats.totalDeleted == 2)
    #expect(h.stats.stats.totalKept == 1)
    #expect(h.stats.stats.bytesDeleted == 350)
    #expect(h.persistence.snapshot == nil)
  }

  @Test func conversionBecomesAPlainKeepOfTheStillCopy() async {
    let h = await finishedSession(
      photoCount: 2, liveIndexes: [1], sizes: [1: 900],
      decisions: [(0, .keep), (1, .convertToStill)])

    await h.vm.confirmSession()

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

  @Test func rejectedCommitLeavesTheSessionUntouched() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .pendingDelete), (2, .keep)])
    h.library.commitFailure = LibraryTestError.rejected

    await h.vm.confirmSession()

    #expect(h.vm.deletionError != nil)
    #expect(h.vm.screen == .pendingReview)
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
    h.library.commitFailure = PHPhotosError(.userCancelled)

    await h.vm.confirmSession()

    #expect(h.vm.deletionError == nil)
    #expect(h.vm.screen == .pendingReview)
    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.stats.stats.sessionsCompleted == 0)
  }

  @Test func aMissingStillCopyReportsAnErrorAndStaysOnPendingReview() async {
    let h = await finishedSession(
      photoCount: 3, liveIndexes: [1, 2],
      decisions: [(0, .keep), (1, .convertToStill), (2, .convertToStill)])
    h.library.photoIDsWithoutStill = [SessionHarness.photoID(2)]

    await h.vm.confirmSession()

    #expect(h.vm.deletionError == PhotoLibraryError.creationFailed.localizedDescription)
    #expect(h.vm.screen == .pendingReview)
    #expect(h.vm.photos[1].decision == .keep)
    #expect(h.vm.photos[1].isLivePhoto == false)
    #expect(h.vm.photos[2].decision == .convertToStill)
    #expect(h.vm.convertedLivePhotoCount == 1)
    #expect(h.stats.stats.sessionsCompleted == 0)
  }
}
