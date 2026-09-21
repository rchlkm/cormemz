// CoreMemsTests/Session/MarkedPhotoTests.swift
import Testing

@testable import CoreMems

@Suite("Marked photos")
@MainActor
struct MarkedPhotoTests {
  @Test func conversionIsMarkedButNotPendingDeletion() async {
    let h = await SessionHarness.started(photoCount: 3, liveIndexes: [1])
    await h.decide(0, .pendingDelete)
    await h.decide(1, .convertToStill)

    #expect(h.vm.pendingItems.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.pendingConversions.map(\.id) == [SessionHarness.photoID(1)])
  }

  @Test func markedPhotosListDeletionsAndConversionsInReviewOrder() async {
    let h = await SessionHarness.started(photoCount: 4, liveIndexes: [1])
    await h.decide(0, .pendingDelete)
    await h.decide(1, .convertToStill)
    await h.decide(2, .keep)
    await h.decide(3, .pendingDelete)

    #expect(
      h.vm.markedPhotos.map(\.id) == [
        SessionHarness.photoID(0), SessionHarness.photoID(1), SessionHarness.photoID(3),
      ])
  }

  @Test func aConversionCountsAsKeptButADeletionDoesNot() async {
    let h = await SessionHarness.started(photoCount: 4, liveIndexes: [1])
    await h.decide(0, .keep)
    await h.decide(1, .convertToStill)
    await h.decide(2, .pendingDelete)

    #expect(h.vm.keptCount == 2)
  }

  @Test func undecidedPhotosAreNotMarked() async {
    let h = await SessionHarness.started(photoCount: 2)

    #expect(h.vm.markedPhotos.isEmpty)
    #expect(h.vm.keptCount == 0)
  }
}
