// CoreMemsTests/Session/OfflineTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Reviewing without a network")
@MainActor
struct OfflineTests {
  @Test func aLivePhotoWithALocalOriginalConvertsOffline() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0], allowsDownloads: false)

    await h.decide(0, .convertToStill)

    #expect(h.vm.canConvertToStill(h.vm.photos[0]))
    #expect(h.vm.photos[0].decision == .convertToStill)
  }

  @Test func aLivePhotoWithoutALocalOriginalCannotConvertOffline() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0], allowsDownloads: false)
    h.library.assetsWithoutLocalOriginal = [SessionHarness.assetID(0)]

    let recording = h.vm.decide(index: 0, decision: .convertToStill)

    #expect(recording == nil)
    #expect(!h.vm.canConvertToStill(h.vm.photos[0]))
    #expect(h.vm.photos[0].decision == .undecided)
  }

  @Test func aLivePhotoWithoutALocalOriginalConvertsOnceDownloadsAreAllowed() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0], allowsDownloads: false)
    h.library.assetsWithoutLocalOriginal = [SessionHarness.assetID(0)]

    h.network.setAllowsDownloads(true)
    #expect(await eventually { h.vm.allowsDownloads })
    await h.decide(0, .convertToStill)

    #expect(h.vm.photos[0].decision == .convertToStill)
  }

  @Test func goingOfflineDropsPhotosAheadThatNeedADownload() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 5)
    h.library.assetsNeedingDownload = [SessionHarness.assetID(3), SessionHarness.assetID(7)]

    h.network.setAllowsDownloads(false)

    #expect(await eventually { h.vm.photos.count == 8 })
    let remaining = Set(h.vm.photos.map(\.assetIdentifier))
    #expect(!remaining.contains(SessionHarness.assetID(3)))
    #expect(!remaining.contains(SessionHarness.assetID(7)))
  }

  @Test func goingOfflineKeepsPhotosAlreadyReviewed() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 5)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)
    h.library.assetsNeedingDownload = [
      SessionHarness.assetID(0), SessionHarness.assetID(1), SessionHarness.assetID(5),
    ]

    h.network.setAllowsDownloads(false)

    #expect(await eventually { h.vm.photos.count == 9 })
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.photos[1].decision == .pendingDelete)
    #expect(h.vm.currentIndex == 2)
  }

  @Test func droppedPhotosStayUnreviewed() async {
    let h = await SessionHarness.started(photoCount: 3)
    h.library.assetsNeedingDownload = [SessionHarness.assetID(1)]
    h.network.setAllowsDownloads(false)
    #expect(await eventually { h.vm.photos.count == 2 })

    for index in 0..<2 { await h.decide(index, .keep) }
    h.vm.finishEarly()
    await h.vm.confirmSession()

    #expect(
      h.reviewedStore.reviewedIdentifiers()
        == [SessionHarness.assetID(0), SessionHarness.assetID(2)])
  }

  @Test func droppingEveryPhotoAheadEndsTheReview() async {
    let h = await SessionHarness.started(photoCount: 3)
    h.library.assetsNeedingDownload = Set((0..<3).map(SessionHarness.assetID))

    h.network.setAllowsDownloads(false)

    #expect(await eventually { h.vm.screen == .pendingReview })
    #expect(h.vm.photos.isEmpty)
  }

  @Test func comingBackOnlineKeepsTheDeck() async {
    let h = await SessionHarness.started(photoCount: 4, allowsDownloads: false)
    h.library.assetsNeedingDownload = [SessionHarness.assetID(2)]

    h.network.setAllowsDownloads(true)
    #expect(await eventually { h.vm.allowsDownloads })
    try? await Task.sleep(for: .milliseconds(100))

    #expect(h.vm.photos.count == 4)
  }

  @Test func startingOfflineWithNothingOnTheDeviceShowsNoPlaceholderPhotos() async {
    let h = SessionHarness(allowsDownloads: false)
    h.vm.eligiblePhotoCount = 5

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.isEmpty)
    #expect(h.vm.screen == .pendingReview)
  }

  @Test func startingOnlineWithAnEmptySourceKeepsThePlaceholderPhotos() async {
    let h = SessionHarness()
    h.vm.eligiblePhotoCount = 5

    await h.vm.startSession(mode: .recent, startDate: nil)

    #expect(h.vm.photos.count == 5)
    #expect(h.vm.screen == .review)
  }

  @Test func settingTheNetworkPolicyUpdatesLiveNetworkAccess() {
    let h = SessionHarness()

    h.vm.networkPolicy = .wifiOnly

    #expect(h.network.policy == .wifiOnly)
  }
}
