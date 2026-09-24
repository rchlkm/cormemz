// CoreMemsTests/Session/PinnedAlbumsViewModelTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Pinned albums settings")
@MainActor
struct PinnedAlbumsViewModelTests {
  private let store = MockPinnedAlbumsStore()

  private let defaults = UserDefaults(suiteName: "pinned-albums-tests-\(UUID().uuidString)")!

  private func makeViewModel() -> PinnedAlbumsViewModel {
    PinnedAlbumsViewModel(library: RecordingPhotoLibrary(), store: store, defaults: defaults)
  }

  @Test func startsWithStoredPins() {
    store.identifiers = ["trips"]

    #expect(makeViewModel().identifiers == ["trips"])
  }

  @Test func togglePersistsBothWays() {
    let pinned = makeViewModel()

    pinned.toggle("trips")
    #expect(store.identifiers == ["trips"])

    pinned.toggle("trips")
    #expect(store.identifiers.isEmpty)
    #expect(pinned.identifiers.isEmpty)
  }

  @Test func createAndPinPinsTheNewAlbumAndNotifies() async {
    let pinned = makeViewModel()
    var notified = false
    pinned.onAlbumCreated = { notified = true }

    await pinned.createAndPin(name: "Trips")?.value

    let created = pinned.albums.map(\.name)
    #expect(created == ["Trips"])
    #expect(pinned.identifiers.count == 1)
    #expect(store.identifiers == pinned.identifiers)
    #expect(pinned.creationError == nil)
    #expect(!pinned.isCreating)
    #expect(notified)
  }

  @Test func pinMergesIntoExistingPins() {
    let pinned = makeViewModel()
    pinned.toggle("trips")

    pinned.pin(["family", "pets"])

    #expect(pinned.identifiers == ["trips", "family", "pets"])
    #expect(store.identifiers == pinned.identifiers)
  }

  @Test func reorderPersistsTheNewOrder() {
    let pinned = makeViewModel()
    pinned.pin(["trips", "family", "pets"])

    pinned.reorder(["pets", "trips", "family"])

    #expect(pinned.identifiers == ["pets", "trips", "family"])
    #expect(store.identifiers == ["pets", "trips", "family"])
  }

  @Test func reorderLeavesPinsOutsideTheSubsetInPlace() {
    let pinned = makeViewModel()
    pinned.pin(["trips", "deleted", "family"])

    pinned.reorder(["family", "trips"])

    #expect(pinned.identifiers == ["family", "deleted", "trips"])
  }

  @Test func sortDefaultsToMyOrderAndPersists() {
    let pinned = makeViewModel()
    #expect(pinned.sort == .myOrder)

    pinned.sort = .recentlyUsed

    #expect(makeViewModel().sort == .recentlyUsed)
  }

  @Test func recentlyUsedPutsNewestFirstThenUnusedInPinOrder() {
    let pinned = makeViewModel()
    pinned.pin(["a", "b", "c", "d"])
    pinned.sort = .recentlyUsed

    let order = pinned.orderedIdentifiers(recents: ["c", "x", "a"])

    #expect(order == ["c", "a", "b", "d"])
  }

  @Test func myOrderIgnoresRecents() {
    let pinned = makeViewModel()
    pinned.pin(["a", "b", "c"])

    #expect(pinned.orderedIdentifiers(recents: ["c", "a"]) == ["a", "b", "c"])
  }
}
