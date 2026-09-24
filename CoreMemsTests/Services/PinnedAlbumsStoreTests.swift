// CoreMemsTests/Services/PinnedAlbumsStoreTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Pinned albums store")
struct PinnedAlbumsStoreTests {
  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("pinned-\(UUID().uuidString).json")

  private func makeStore() -> PinnedAlbumsStore { PinnedAlbumsStore(fileURL: fileURL) }

  @Test func pinAppendsNewAlbumsInOrder() {
    let store = makeStore()

    store.pin(["b", "a"])
    store.pin(["c", "b"])

    #expect(store.pinnedAlbumIdentifiers() == ["b", "a", "c"])
  }

  @Test func unpinKeepsTheRemainingOrder() {
    let store = makeStore()
    store.pin(["a", "b", "c"])

    store.unpin("b")

    #expect(store.pinnedAlbumIdentifiers() == ["a", "c"])
  }

  @Test func orderSurvivesReloading() {
    makeStore().setOrder(["c", "a", "b"])

    #expect(makeStore().pinnedAlbumIdentifiers() == ["c", "a", "b"])
  }
}
