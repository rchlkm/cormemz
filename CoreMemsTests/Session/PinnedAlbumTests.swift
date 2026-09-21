// CoreMemsTests/Session/PinnedAlbumTests.swift
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

    h.vm.togglePinnedAlbum("trips")

    #expect(h.vm.pinnedAlbumIdentifiers == ["trips"])
    #expect(h.vm.quickAccessAlbums == [trips])
  }

  @Test func unpinningAnAlbumRemovesItFromQuickAccess() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.libraryAlbums = [trips]
    h.vm.togglePinnedAlbum("trips")

    h.vm.togglePinnedAlbum("trips")

    #expect(h.vm.pinnedAlbumIdentifiers.isEmpty)
    #expect(h.vm.quickAccessAlbums.isEmpty)
  }
}
