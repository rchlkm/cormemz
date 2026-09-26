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

  @Test func loadFetchesAlbumGroups() async {
    let library = RecordingPhotoLibrary()
    let views = AlbumGroup(identifier: "views", name: "Views", albumIdentifiers: ["trees"])
    library.albumGroups = [views]
    let pinned = PinnedAlbumsViewModel(library: library, store: store, defaults: defaults)

    pinned.load()
    while pinned.isLoading { await Task.yield() }

    #expect(pinned.groups == [views])
  }

  @Test func loadUnpinsIdentifiersThatAreNotLibraryAlbums() async {
    let library = RecordingPhotoLibrary()
    library.albumGroups = [AlbumGroup(identifier: "views", name: "Views", albumIdentifiers: ["a"])]
    library.albums = [AlbumOption(ref: .existing(localIdentifier: "a"), name: "A")]
    store.identifiers = ["views", "deleted", "a"]
    let pinned = PinnedAlbumsViewModel(library: library, store: store, defaults: defaults)

    pinned.load()
    while pinned.isLoading { await Task.yield() }

    #expect(pinned.identifiers == ["a"])
    #expect(store.identifiers == ["a"])
  }

  @Test func pruneUnpinsAlbumsMissingFromTheLibrary() {
    store.identifiers = ["trips", "deleted", "family"]
    let pinned = makeViewModel()
    let library = ["trips", "family", "other"].map {
      AlbumOption(ref: .existing(localIdentifier: $0), name: $0)
    }

    pinned.prune(albums: library)

    #expect(pinned.identifiers == ["trips", "family"])
    #expect(store.identifiers == ["trips", "family"])
  }

  @Test func pruneKeepsEveryPinWhenTheLibraryIsEmpty() {
    store.identifiers = ["trips", "family"]
    let pinned = makeViewModel()

    pinned.prune(albums: [])

    #expect(pinned.identifiers == ["trips", "family"])
    #expect(store.identifiers == ["trips", "family"])
  }

  @Test func folderPathsListEnclosingFoldersOutermostFirst() async {
    let library = RecordingPhotoLibrary()
    let trips = AlbumGroup(
      identifier: "trips", name: "Trips", albumIdentifiers: [], groupIdentifiers: ["y2024"])
    let year = AlbumGroup(identifier: "y2024", name: "2024", albumIdentifiers: ["japan"])
    library.albumGroups = [trips, year]
    let pinned = PinnedAlbumsViewModel(library: library, store: store, defaults: defaults)

    pinned.load()
    while pinned.isLoading { await Task.yield() }

    #expect(pinned.folderPathsByChildID["japan"]?.map(\.name) == ["Trips", "2024"])
    #expect(pinned.folderPathsByChildID["y2024"]?.map(\.name) == ["Trips"])
    #expect(pinned.folderPathsByChildID["trips"] == nil)
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
