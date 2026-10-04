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

  @Test func keptPhotosAreRemembered() async {
    let h = await finishedSession(
      photoCount: 3, decisions: [(0, .keep), (1, .pendingDelete), (2, .keep)])

    await h.vm.applyChanges()

    #expect(
      h.keptStore.keptIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
    #expect(h.vm.keptPhotoCount == 2)
  }

  @Test func trackingOffLeavesKeptHistoryUntouched() async {
    let h = await finishedSession(photoCount: 2, decisions: [(0, .keep), (1, .keep)])
    h.vm.tracksKeptHistory = false

    await h.vm.applyChanges()

    #expect(h.keptStore.keptIdentifiers().isEmpty)
    #expect(h.vm.keptPhotoCount == 0)
  }

  @Test func photosHeldForLaterAreNotRemembered() async {
    let h = await finishedSession(photoCount: 3, decisions: [(0, .keep), (1, .keep), (2, .keep)])
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(1))

    await h.vm.applyChanges()

    #expect(
      h.keptStore.keptIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
  }

  @Test func togglingHeldForLaterTwiceRemembersThePhotoAgain() async {
    let h = await finishedSession(photoCount: 1, decisions: [(0, .keep)])
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(0))
    h.vm.toggleHeldForLater(photoID: SessionHarness.photoID(0))

    await h.vm.applyChanges()

    #expect(h.keptStore.keptIdentifiers() == [SessionHarness.assetID(0)])
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

  /// A started session where every photo is kept and those at `editedIndexes` are rotated once.
  private var trim: MediaEdit {
    var edit = MediaEdit()
    edit.trim(to: 1...3, ofDuration: 10)
    return edit
  }

  private func sessionWithEdits(photoCount: Int, editedIndexes: [Int]) async -> SessionHarness {
    let h = await SessionHarness.started(photoCount: photoCount)
    var edit = MediaEdit()
    edit.rotate()
    for index in editedIndexes {
      h.vm.saveEdit(edit, photoID: SessionHarness.photoID(index))
    }
    for index in 0..<photoCount { await h.decide(index, .keep) }
    return h
  }

  @Test func editsAreWrittenInTheSameCommitAsDeletions() async {
    let h = await SessionHarness.started(photoCount: 2)
    var edit = MediaEdit()
    edit.rotate()
    h.vm.saveEdit(edit, photoID: SessionHarness.photoID(0))
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    await h.vm.applyChanges()

    #expect(h.library.events.filter { $0 == .apply }.count == 1)
    let changes = h.library.appliedChanges.first
    #expect(changes?.edits.keys.sorted() == [SessionHarness.photoID(0)])
    #expect(changes?.edits[SessionHarness.photoID(0)]?.edit == edit)
    #expect(changes?.deletions.map(\.localIdentifier) == [SessionHarness.assetID(1)])
    #expect(h.vm.screen == .completion)
  }

  @Test func anEditOnAnUndecidedPhotoIsStillWritten() async {
    let h = await SessionHarness.started(photoCount: 2)
    var edit = MediaEdit()
    edit.rotate()
    h.vm.saveEdit(edit, photoID: SessionHarness.photoID(1))
    await h.decide(0, .keep)
    h.vm.finishEarly()

    await h.vm.applyChanges()

    #expect(h.library.appliedChanges.first?.edits.keys.sorted() == [SessionHarness.photoID(1)])
  }

  @Test func anEditedAndKeptPhotoCountsOnceAsKeptAndOnceAsEdited() async {
    let h = await sessionWithEdits(photoCount: 2, editedIndexes: [0])

    await h.vm.applyChanges()

    #expect(h.vm.keptCount == 2)
    #expect(h.vm.editedCount == 1)
    #expect(h.stats.stats.keptUnchanged == 2)
    #expect(h.stats.stats.mediaEdited == 1)
    #expect(
      h.keptStore.keptIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(1)])
  }

  @Test func anUndoneEditIsNotWritten() async {
    let h = await sessionWithEdits(photoCount: 2, editedIndexes: [0, 1])
    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    await h.vm.applyChanges()

    #expect(h.library.appliedChanges.first?.edits.keys.sorted() == [SessionHarness.photoID(1)])
    #expect(h.vm.editedCount == 1)
  }

  @Test func anEditThatFailsToRenderIsReportedAndNotCounted() async {
    let h = await sessionWithEdits(photoCount: 3, editedIndexes: [0, 1])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(1)]

    await h.vm.applyChanges()

    #expect(h.vm.screen == .completion)
    #expect(h.vm.failedEditCount == 1)
    #expect(h.vm.editedCount == 1)
    #expect(h.stats.stats.mediaEdited == 1)
    #expect(h.stats.stats.sessionsCompleted == 1)
  }

  @Test func aFailedEditIsListedWithItsDecisionAndReason() async {
    let h = await sessionWithEdits(photoCount: 2, editedIndexes: [0, 1])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(1)]
    h.library.editFailureReason = .needsDownload

    await h.vm.applyChanges()

    let failure = h.vm.failedEdits.first
    #expect(h.vm.failedEdits.map(\.id) == [SessionHarness.photoID(1)])
    #expect(failure?.photo.decision == .keep)
    #expect(failure?.photo.activeEdit?.quarterTurns == 1)
    #expect(failure?.reason == .needsDownload)
    #expect(failure?.attempts == 1)
  }

  @Test func retryingAFailedEditWritesOnlyThatEditAndCountsIt() async {
    let h = await sessionWithEdits(photoCount: 2, editedIndexes: [0, 1])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(1)]
    await h.vm.applyChanges()
    h.library.photoIDsWithFailedEdit = []

    let stillFailing = await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(1)])

    #expect(stillFailing.isEmpty)
    #expect(h.library.appliedChanges.last?.edits.keys.sorted() == [SessionHarness.photoID(1)])
    #expect(h.library.appliedChanges.last?.deletions.isEmpty == true)
    #expect(h.vm.failedEdits.isEmpty)
    #expect(h.vm.editedCount == 2)
    #expect(h.stats.stats.mediaEdited == 2)
  }

  @Test func anEditThatFailsAgainStaysListedWithItsNewReasonAndAttempt() async {
    let h = await sessionWithEdits(photoCount: 1, editedIndexes: [0])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]
    await h.vm.applyChanges()
    h.library.editFailureReason = .needsDownload

    let stillFailing = await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])

    #expect(stillFailing == [SessionHarness.photoID(0): .needsDownload])
    #expect(h.vm.failedEdits.first?.reason == .needsDownload)
    #expect(h.vm.failedEdits.first?.attempts == 2)
    #expect(h.vm.editedCount == 0)
    #expect(h.stats.stats.mediaEdited == 0)
  }

  @Test func decliningTheRetryPromptIsReportedAsDeclined() async {
    let h = await sessionWithEdits(photoCount: 1, editedIndexes: [0])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]
    await h.vm.applyChanges()
    h.library.photoIDsWithFailedEdit = []
    h.library.applyFailure = PHPhotosError(.userCancelled)

    let stillFailing = await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])

    #expect(stillFailing == [SessionHarness.photoID(0): .declined])
    #expect(h.vm.failedEdits.first?.reason == .declined)
  }

  @Test func aRejectedRetryKeepsTheEditListed() async {
    let h = await sessionWithEdits(photoCount: 1, editedIndexes: [0])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]
    await h.vm.applyChanges()
    h.library.photoIDsWithFailedEdit = []
    h.library.applyFailure = LibraryTestError.rejected

    let stillFailing = await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])

    #expect(stillFailing == [SessionHarness.photoID(0): .unknown])
    #expect(h.vm.failedEdits.count == 1)
  }

  @Test func discardingAFailedEditDropsItWithoutTouchingTheLibrary() async {
    let h = await sessionWithEdits(photoCount: 2, editedIndexes: [0, 1])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0), SessionHarness.photoID(1)]
    await h.vm.applyChanges()
    let applies = h.library.appliedChanges.count

    h.vm.discardFailedEdit(photoID: SessionHarness.photoID(0))

    #expect(h.vm.failedEdits.map(\.id) == [SessionHarness.photoID(1)])
    #expect(h.library.appliedChanges.count == applies)
    #expect(h.vm.editedCount == 0)
  }

  @Test func aFailedEditGetsTheFailureFeedbackInsteadOfTheCompletionOne() async {
    let h = await sessionWithEdits(photoCount: 1, editedIndexes: [0])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]

    await h.vm.applyChanges()

    #expect(h.haptics.editFailedCount == 1)
    #expect(h.haptics.sessionCompleteCallCount == 0)
  }

  @Test func aTrimmedClipIsRememberedAsKept() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.saveEdit(trim, photoID: SessionHarness.photoID(0))
    await h.decide(0, .keep)
    await h.decide(1, .keep)

    await h.vm.applyChanges()

    #expect(
      h.keptStore.keptIdentifiers()
        == ["clip-\(SessionHarness.assetID(0))", SessionHarness.assetID(0),
          SessionHarness.assetID(1)])
    #expect(h.vm.keptPhotoCount == 3)
  }

  @Test func aTrimmedClipWrittenOnRetryIsRememberedAsKept() async {
    let h = await SessionHarness.started(photoCount: 1)
    h.vm.saveEdit(trim, photoID: SessionHarness.photoID(0))
    await h.decide(0, .keep)
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]
    await h.vm.applyChanges()
    #expect(h.keptStore.keptIdentifiers() == [SessionHarness.assetID(0)])
    h.library.photoIDsWithFailedEdit = []

    await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])

    #expect(
      h.keptStore.keptIdentifiers()
        == ["clip-\(SessionHarness.assetID(0))", SessionHarness.assetID(0)])
  }

  @Test func aTrimmedClipIsNotRememberedWithTrackingOff() async {
    let h = await SessionHarness.started(photoCount: 1)
    h.vm.tracksKeptHistory = false
    h.vm.saveEdit(trim, photoID: SessionHarness.photoID(0))
    await h.decide(0, .keep)

    await h.vm.applyChanges()

    #expect(h.keptStore.keptIdentifiers().isEmpty)
  }

  @Test func retryFeedbackFollowsTheOutcome() async {
    let h = await sessionWithEdits(photoCount: 1, editedIndexes: [0])
    h.library.photoIDsWithFailedEdit = [SessionHarness.photoID(0)]
    await h.vm.applyChanges()
    let keepsBefore = h.haptics.keepCallCount

    await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])
    #expect(h.haptics.editFailedCount == 2)

    h.library.photoIDsWithFailedEdit = []
    await h.vm.retryEdits(photoIDs: [SessionHarness.photoID(0)])
    #expect(h.haptics.keepCallCount == keepsBefore + 1)
  }
}
