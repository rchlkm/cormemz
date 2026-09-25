// CoreMemsTests/Services/SessionSnapshotMappingTests.swift
import Testing

@testable import CoreMems

@Suite("Session snapshot mapping")
struct SessionSnapshotMappingTests {
  @Test func aSnapshotRoundTripsTheSessionState() {
    var photo = SessionPhoto(id: "p1", assetIdentifier: "a1", previewURL: nil)
    photo.decision = .pendingDelete
    let history = [
      DecisionHistoryEntry(
        photoIndex: 0, previousDecision: .undecided, newDecision: .pendingDelete, advancedIndex: true)
    ]
    var staging = AlbumStaging()
    staging.createPendingAlbum(name: "Hikes", assignTo: "p1")

    let deck = SessionDeck(photos: [photo], currentIndex: 1, history: history)

    let snapshot = PersistedSessionSnapshot(deck: deck, albumStaging: staging)

    let restored = snapshot.restoredDeck
    #expect(restored.photos == [photo])
    #expect(restored.currentIndex == 1)
    #expect(restored.history.map(\.newDecision) == [.pendingDelete])
    #expect(restored.history.map(\.advancedIndex) == [true])
    #expect(snapshot.restoredAlbumStaging.pendingNewAlbums.map(\.name) == ["Hikes"])
    #expect(snapshot.restoredAlbumStaging.pendingNewAlbums[0].assetCount == 1)
  }
}
