// CoreMemsTests/Session/PersistenceTests.swift
import Testing

@testable import CoreMems

@Suite("Saving and resuming a session")
@MainActor
struct PersistenceTests {
  @Test func everyDecisionIsSaved() async throws {
    let h = await SessionHarness.started(photoCount: 3)

    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    let snapshot = try #require(h.persistence.snapshot)
    #expect(snapshot.decisions == ["keep", "pendingDelete", "undecided"])
    #expect(snapshot.currentIndex == 2)
    #expect(snapshot.photoIDs == (0..<3).map(SessionHarness.photoID))
    #expect(snapshot.assetIdentifiers == (0..<3).map(SessionHarness.assetID))
    #expect(snapshot.historyPhotoIndices == [0, 1])
    #expect(snapshot.historyPrevious == ["undecided", "undecided"])
    #expect(snapshot.historyNew == ["keep", "pendingDelete"])
    #expect(snapshot.historyAdvanced == [true, true])
  }

  @Test func goingBackIsSaved() async throws {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)

    h.vm.goBack()

    let snapshot = try #require(h.persistence.snapshot)
    #expect(snapshot.decisions.first == "keep")
    #expect(snapshot.currentIndex == 0)
    #expect(snapshot.historyPhotoIndices.isEmpty)
  }

  @Test func aNewViewModelResumesTheSavedSession() async {
    let h = await SessionHarness.started(photoCount: 4)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .review)
    #expect(resumed.photos.map(\.id) == (0..<4).map(SessionHarness.photoID))
    #expect(resumed.photos.map(\.decision) == [.keep, .pendingDelete, .undecided, .undecided])
    #expect(resumed.currentIndex == 2)
    #expect(resumed.history.count == 2)
    #expect(resumed.pendingItems.map(\.id) == [SessionHarness.photoID(1)])
  }

  @Test func goingBackWorksAfterResuming() async {
    let h = await SessionHarness.started(photoCount: 4)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)
    let resumed = SessionHarness(persistence: h.persistence).vm

    resumed.goBack()

    #expect(resumed.photos[1].decision == .pendingDelete)
    #expect(resumed.currentIndex == 1)
    #expect(resumed.canGoBack)
  }

  @Test func aSessionSavedAtTheEndOfTheDeckResumesOnPendingReview() async {
    let h = await SessionHarness.started(photoCount: 2)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .pendingReview)
    #expect(resumed.pendingItems.count == 1)
  }

  @Test func withNothingSavedTheAppStartsOnHome() {
    let vm = SessionHarness().vm

    #expect(vm.screen == .home)
    #expect(vm.photos.isEmpty)
  }

  @Test func confirmingTheSessionClearsTheSavedState() async {
    let h = await SessionHarness.started(photoCount: 2)
    await h.decide(0, .keep)
    await h.decide(1, .keep)

    await h.vm.confirmSession()

    #expect(h.persistence.snapshot == nil)
    #expect(SessionHarness(persistence: h.persistence).vm.screen == .home)
  }

  @Test func leavingForSetupClearsTheSavedState() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)

    h.vm.exitToSetup()

    #expect(h.vm.screen == .setup)
    #expect(h.persistence.snapshot == nil)
  }
}
