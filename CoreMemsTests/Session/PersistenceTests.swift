// CoreMemsTests/Session/PersistenceTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Saving and resuming a session")
@MainActor
struct PersistenceTests {
  private static func library(photoCount: Int) -> RecordingPhotoLibrary {
    let library = RecordingPhotoLibrary()
    library.assets = (0..<photoCount).map { FakeAsset(identifier: SessionHarness.assetID($0)) }
    return library
  }

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

  @Test func aNewViewModelResumesTheSavedSessionOnPendingChanges() async {
    let h = await SessionHarness.started(photoCount: 4)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .pendingChanges)
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

  @Test func aSessionSavedAtTheEndOfTheDeckResumesOnPendingChanges() async {
    let h = await SessionHarness.started(photoCount: 2)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .pendingChanges)
    #expect(resumed.pendingItems.count == 1)
  }

  @Test func aSessionWithOnlyAlbumChangesResumesOnPendingChanges() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)
    h.vm.toggleAlbumMembership(
      photoID: SessionHarness.photoID(0), ref: .existing(localIdentifier: "album-1"))

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .pendingChanges)
  }

  @Test func aSessionWithNoChangesResumesOnHomeAndIsDropped() async {
    let h = await SessionHarness.started(photoCount: 4)
    await h.decide(0, .keep)
    await h.decide(1, .keep)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.screen == .home)
    #expect(resumed.photos.isEmpty)
    #expect(h.persistence.snapshot == nil)
  }

  @Test func aDroppedSessionHandsItsFiltersToHome() async {
    let album = AlbumOption(ref: .existing(localIdentifier: "album-1"), name: "Trip")
    let h = SessionHarness(library: Self.library(photoCount: 3))
    await h.vm.startSession(mode: .album, startDate: nil, album: album, mediaTypes: [.videos])
    await h.decide(0, .keep)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(
      resumed.interruptedSessionFilters
        == SessionFilters(
          mode: .album, startDate: nil, album: SessionFilters.Album(album), mediaTypes: [.videos]))
  }

  @Test func aDroppedDateSessionKeepsItsStartDate() async {
    let date = Date(timeIntervalSince1970: 1_000_000)
    let h = SessionHarness(library: Self.library(photoCount: 3))
    await h.vm.startSession(mode: .date, startDate: date)
    await h.decide(0, .keep)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.interruptedSessionFilters?.mode == .date)
    #expect(resumed.interruptedSessionFilters?.startDate == date)
  }

  @Test func aSessionResumedWithChangesHandsHomeNoFilters() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)

    let resumed = SessionHarness(persistence: h.persistence).vm

    #expect(resumed.interruptedSessionFilters == nil)
  }

  @Test func startingASessionClearsTheInterruptedFilters() async {
    let h = await SessionHarness.started(photoCount: 3, mode: .recent)
    await h.decide(0, .keep)
    let resumed = SessionHarness(library: Self.library(photoCount: 3), persistence: h.persistence).vm
    #expect(resumed.interruptedSessionFilters?.mode == .recent)

    await resumed.startSession(mode: .shuffle, startDate: nil)

    #expect(resumed.interruptedSessionFilters == nil)
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

    await h.vm.applyChanges()

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
