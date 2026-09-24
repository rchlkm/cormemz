// CoreMemsTests/Session/PinnedAlbumTests.swift
import Combine
import Testing

@testable import CoreMems

@Suite("Pinning albums during review")
@MainActor
struct PinnedAlbumTests {
  private let trips = AlbumOption(ref: .existing(localIdentifier: "trips"), name: "Trips")

  @Test func pinningAnAlbumAddsItToQuickAccess() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.libraryAlbums = [trips]
    #expect(h.vm.quickAccessAlbums.isEmpty)

    h.vm.pinnedAlbums.toggle("trips")

    #expect(h.vm.pinnedAlbums.identifiers == ["trips"])
    #expect(h.vm.quickAccessAlbums == [trips])
  }

  @Test func unpinningAnAlbumRemovesItFromQuickAccess() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.libraryAlbums = [trips]
    h.vm.pinnedAlbums.toggle("trips")

    h.vm.pinnedAlbums.toggle("trips")

    #expect(h.vm.pinnedAlbums.identifiers.isEmpty)
    #expect(h.vm.quickAccessAlbums.isEmpty)
  }

  @Test func quickAccessListsPinsInPinOrderThenUnpinnedRecents() async {
    let h = await SessionHarness.started(photoCount: 2)
    let family = AlbumOption(ref: .existing(localIdentifier: "family"), name: "Family")
    let pets = AlbumOption(ref: .existing(localIdentifier: "pets"), name: "Pets")
    h.vm.libraryAlbums = [family, pets, trips]
    h.vm.pinnedAlbums.pin(["trips", "family"])
    h.vm.toggleAlbumMembership(photoID: SessionHarness.photoID(0), ref: pets.ref)

    #expect(h.vm.quickAccessAlbums == [trips, family, pets])

    h.vm.pinnedAlbums.reorder(["family", "trips"])

    #expect(h.vm.quickAccessAlbums == [family, trips, pets])
  }

  @Test func recentlyUsedSortPutsTheLatestPickFirstInQuickAccess() async {
    let h = await SessionHarness.started(photoCount: 2)
    let family = AlbumOption(ref: .existing(localIdentifier: "family"), name: "Family")
    h.vm.libraryAlbums = [family, trips]
    h.vm.pinnedAlbums.pin(["trips", "family"])
    h.vm.pinnedAlbums.sort = .recentlyUsed
    defer { h.vm.pinnedAlbums.sort = .myOrder }
    h.vm.toggleAlbumMembership(photoID: SessionHarness.photoID(0), ref: family.ref)

    #expect(h.vm.quickAccessAlbums == [family, trips])
  }

  @Test func pinChangesNotifySessionObservers() async {
    let h = await SessionHarness.started(photoCount: 2)
    var notifications = 0
    let observation = h.vm.objectWillChange.sink { notifications += 1 }
    defer { observation.cancel() }

    h.vm.pinnedAlbums.toggle("trips")
    #expect(notifications == 1)

    h.vm.pinnedAlbums.reorder(["trips"])
    #expect(notifications == 1)
  }

  @Test func loadingPinnedAlbumsDoesNotNotifySessionObservers() async {
    let h = await SessionHarness.started(photoCount: 2)
    var notifications = 0
    let observation = h.vm.objectWillChange.sink { notifications += 1 }
    defer { observation.cancel() }

    h.vm.pinnedAlbums.load()

    #expect(notifications == 0)
  }
}
