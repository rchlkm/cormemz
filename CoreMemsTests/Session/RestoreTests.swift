// CoreMemsTests/Session/RestoreTests.swift
import Testing

@testable import CoreMems

@Suite("Restoring marked photos")
@MainActor
struct RestoreTests {
  @Test func restoreTurnsDeletionsAndConversionsBackIntoKeeps() async {
    let h = await SessionHarness.started(photoCount: 4, liveIndexes: [1])
    await h.decide(0, .pendingDelete)
    await h.decide(1, .convertToStill)

    h.vm.restoreMany(ids: [SessionHarness.photoID(0), SessionHarness.photoID(1)])

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.photos[1].decision == .keep)
    #expect(h.vm.markedPhotos.isEmpty)
    #expect(h.haptics.trayRestoreCallCount == 1)
  }

  @Test func restoreLeavesTheReviewIndexAlone() async {
    let h = await SessionHarness.started(photoCount: 4)
    await h.decide(0, .pendingDelete)
    await h.decide(1, .keep)

    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    #expect(h.vm.currentIndex == 2)
    #expect(h.vm.history.last?.advancedIndex == false)
    #expect(h.vm.history.last?.previousDecision == .pendingDelete)
    #expect(h.vm.history.last?.newDecision == .keep)
  }

  @Test func restoreIgnoresKeptAndUnknownPhotos() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)
    let historyBefore = h.vm.history.count

    h.vm.restoreMany(ids: [SessionHarness.photoID(0), "not-a-photo"])

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.history.count == historyBefore)
    #expect(h.haptics.trayRestoreCallCount == 0)
  }

  @Test func restoreWithNoIDsDoesNothing() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)
    let snapshotBefore = h.persistence.snapshot?.decisions

    h.vm.restoreMany(ids: [])

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.haptics.trayRestoreCallCount == 0)
    #expect(h.persistence.snapshot?.decisions == snapshotBefore)
  }

  @Test func restoreIsSavedWithTheSession() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)

    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    #expect(h.persistence.snapshot?.decisions.first == ReviewDecision.keep.rawValue)
  }
}
