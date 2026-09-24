// CoreMemsTests/Session/NeighborLookupTests.swift
import Testing

@testable import CoreMems

@Suite("Neighbor lookup")
@MainActor
struct NeighborLookupTests {
  @Test func discoversNeighborsNotYetLoadedIntoTheSession() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    // Only the first two lookahead batches (4 photos) are loaded initially.
    #expect(h.vm.photos.count == 4)

    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), before: 2, after: 2)

    // Window is library indices 1...5 — indices 4 and 5 weren't loaded into the
    // session yet, so this must reach into the library directly to find them.
    #expect(neighbors.map(\.assetIdentifier) == (1...5).map(SessionHarness.assetID))
    #expect(h.vm.photos.count == 4)
  }

  @Test func reusesAnAlreadyTrackedNeighborRatherThanDuplicatingIt() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let existingID = SessionHarness.photoID(2)

    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), before: 1, after: 1)

    let match = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(2) }
    #expect(match?.id == existingID)
    #expect(h.vm.photos.filter { $0.assetIdentifier == SessionHarness.assetID(2) }.count == 1)
  }

  @Test func hasNoNeighborsForAPhotoWithoutARealAsset() async {
    let h = await SessionHarness.started(photoCount: 3)
    let neighbors = await h.vm.neighborPhotos(of: "not-a-real-photo-id", before: 2, after: 2)
    #expect(neighbors.isEmpty)
  }

  @Test func decidingOnADiscoveredNeighborByIDMarksItWithoutAdvancingCurrentIndex() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), before: 2, after: 2)
    let discovered = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(5) }

    #expect(discovered != nil)
    await h.vm.decide(photoID: discovered!.id, decision: .pendingDelete)?.value

    #expect(h.vm.markedPhotos.contains { $0.id == discovered!.id })
    #expect(h.vm.photos[h.vm.currentIndex].id == SessionHarness.photoID(0))
  }

  @Test func aDecidedNeighborIsNotServedAgainByALaterBatch() async {
    let h = await SessionHarness.started(photoCount: 10, batchSize: 2)
    let neighbors = await h.vm.neighborPhotos(of: SessionHarness.photoID(3), before: 2, after: 2)
    let discovered = neighbors.first { $0.assetIdentifier == SessionHarness.assetID(5) }!
    await h.vm.decide(photoID: discovered.id, decision: .keep)?.value

    for _ in 0..<8 { await h.vm.decide(index: h.vm.currentIndex, decision: .keep)?.value }

    #expect(h.vm.photos.filter { $0.assetIdentifier == SessionHarness.assetID(5) }.count == 1)
  }
}
