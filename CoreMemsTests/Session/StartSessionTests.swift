// CoreMemsTests/Session/StartSessionTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Starting a session")
@MainActor
struct StartSessionTests {
  private func harness(assetCount: Int, reviewed: Set<Int> = []) -> SessionHarness {
    let library = RecordingPhotoLibrary()
    library.assets = (0..<assetCount).map { FakeAsset(identifier: SessionHarness.assetID($0)) }
    let h = SessionHarness(library: library)
    h.reviewedStore.markReviewed(Set(reviewed.map(SessionHarness.assetID)))
    h.vm.eligiblePhotoCount = assetCount
    return h
  }

  @Test func photosKeptInEarlierSessionsAreSkipped() async {
    let h = harness(assetCount: 3, reviewed: [0])

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.map(\.assetIdentifier) == [SessionHarness.assetID(1), SessionHarness.assetID(2)])
  }

  @Test func reviewedPhotosCanBeIncluded() async {
    let h = harness(assetCount: 3, reviewed: [0])
    h.vm.includesReviewedPhotos = true

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.count == 3)
  }

  @Test func aLibraryReviewedInFullIsShownAgainRatherThanEmpty() async {
    let h = harness(assetCount: 3, reviewed: [0, 1, 2])

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.count == 3)
    #expect(h.vm.screen == .review)
  }

  @Test func anEmptyLibraryFallsBackToPlaceholderPhotos() async {
    let h = harness(assetCount: 0)
    h.vm.eligiblePhotoCount = 3

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.map(\.id) == ["mock-0", "mock-1", "mock-2"])
    #expect(h.vm.screen == .review)
  }

  @Test func theLabelDescribesHowPhotosWereChosen() async {
    let h = harness(assetCount: 2)
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    await h.vm.startSession(mode: .shuffle, startDate: nil)
    #expect(h.vm.sessionLabel == nil)

    await h.vm.startSession(mode: .recent, startDate: nil)
    #expect(h.vm.sessionLabel == "Most recent first")

    await h.vm.startSession(mode: .date, startDate: date)
    #expect(h.vm.sessionLabel == "From \(SessionViewModel.cardDateFormatter.string(from: date))")
  }

  @Test func aNewSessionClearsThePreviousOnesCounts() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)
    await h.vm.confirmDeletion()
    #expect(h.vm.deletedCount == 1)

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.deletedCount == 0)
    #expect(h.vm.albumAssignedCount == 0)
    #expect(h.vm.convertedLivePhotoCount == 0)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canGoBack == false)
  }
}
