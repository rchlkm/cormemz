// CoreMemsTests/Session/StartSessionTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Starting a session")
@MainActor
struct StartSessionTests {
  private func harness(assetCount: Int, kept: Set<Int> = []) -> SessionHarness {
    let library = RecordingPhotoLibrary()
    library.assets = (0..<assetCount).map { FakeAsset(identifier: SessionHarness.assetID($0)) }
    let h = SessionHarness(library: library)
    h.keptStore.markKept(Set(kept.map(SessionHarness.assetID)))
    h.vm.eligiblePhotoCount = assetCount
    return h
  }

  @Test func photosKeptInEarlierSessionsAreSkipped() async {
    let h = harness(assetCount: 3, kept: [0])

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.map(\.assetIdentifier) == [SessionHarness.assetID(1), SessionHarness.assetID(2)])
  }

  @Test func photoIDsAreTheAssetIdentifiers() async {
    let h = harness(assetCount: 3)

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.map(\.id) == h.vm.photos.map(\.assetIdentifier))
  }

  @Test func keptPhotosCanBeIncluded() async {
    let h = harness(assetCount: 3, kept: [0])
    h.vm.includesKeptPhotos = true

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.count == 3)
  }

  @Test func aLibraryKeptInFullIsShownAgainRatherThanEmpty() async {
    let h = harness(assetCount: 3, kept: [0, 1, 2])

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.count == 3)
    #expect(h.vm.screen == .browse)
  }

  @Test func anEmptyLibraryFallsBackToPlaceholderPhotos() async {
    let h = harness(assetCount: 0)
    h.vm.eligiblePhotoCount = 3

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.map(\.id) == ["mock-0", "mock-1", "mock-2"])
    #expect(h.vm.screen == .browse)
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

    let album = AlbumOption(ref: .existing(localIdentifier: "album-1"), name: "Road Trip")
    await h.vm.startSession(mode: .album, startDate: nil, album: album)
    #expect(h.vm.sessionLabel == "Road Trip")
  }

  @Test func mediaTypesReachTheLibrary() async {
    let h = harness(assetCount: 3)

    await h.vm.startSession(mode: .recent, startDate: nil, mediaTypes: [.screenshots, .videos])

    #expect(h.library.lastMediaTypes == [.screenshots, .videos])
  }

  @Test func noMediaTypesReachTheLibraryAsAnEmptySet() async {
    let h = harness(assetCount: 3)

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.library.lastMediaTypes == [])
  }

  @Test func aVideoAssetProducesAVideoSessionPhoto() async {
    let library = RecordingPhotoLibrary()
    library.assets = [FakeAsset(identifier: SessionHarness.assetID(0), isVideo: true)]
    let h = SessionHarness(library: library)
    h.vm.eligiblePhotoCount = 1

    await h.vm.startSession(mode: .recent, startDate: nil, mediaTypes: [.videos])

    #expect(h.vm.photos.map(\.isVideo) == [true])
  }

  @Test func aNewSessionClearsThePreviousOnesCounts() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)
    await h.vm.applyChanges()
    #expect(h.vm.deletedCount == 1)

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.deletedCount == 0)
    #expect(h.vm.albumAssignedCount == 0)
    #expect(h.vm.convertedLivePhotoCount == 0)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canGoBack == false)
  }
}
