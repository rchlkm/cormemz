// CoreMemsTests/Session/PinnedDisplayItemTests.swift
import Testing

@testable import CoreMems

@Suite("Pinned display items")
struct PinnedDisplayItemTests {
  private func album(_ id: String) -> AlbumOption {
    AlbumOption(ref: .existing(localIdentifier: id), name: id)
  }

  private let trips = AlbumGroup(
    identifier: "trips", name: "Trips", albumIdentifiers: ["japan", "peru", "iceland"])

  private func items(_ identifiers: [String], groups: [AlbumGroup]? = nil) -> [PinnedDisplayItem] {
    PinnedDisplayItem.items(
      identifiers: identifiers,
      albums: ["japan", "peru", "iceland", "family"].map(album),
      groups: groups ?? [trips])
  }

  @Test func aLoneAlbumFromAFolderStaysAnAlbum() {
    #expect(items(["japan", "family"]) == [.album(album("japan")), .album(album("family"))])
  }

  @Test func albumsSharingAFolderCollapseAtTheFirstMembersPosition() {
    let result = items(["family", "peru", "trips-less", "japan"])

    #expect(
      result == [
        .album(album("family")),
        .collapsedFolder(trips, albums: [album("peru"), album("japan")]),
      ])
  }

  @Test func pinnedFolderIdentifiersAreIgnored() {
    let result = items(["trips", "family"])

    #expect(result == [.album(album("family"))])
  }

  @Test func collapsingUsesTheDirectParentOnly() {
    let year = AlbumGroup(identifier: "y2024", name: "2024", albumIdentifiers: ["japan", "peru"])
    let outer = AlbumGroup(
      identifier: "trips", name: "Trips", albumIdentifiers: ["iceland"],
      groupIdentifiers: ["y2024"])

    let result = items(["japan", "iceland", "peru"], groups: [outer, year])

    #expect(
      result == [
        .collapsedFolder(year, albums: [album("japan"), album("peru")]),
        .album(album("iceland")),
      ])
  }

  @Test func aCollapsedFolderStandsForItsPinnedAlbums() {
    let result = items(["japan", "peru"])

    #expect(result.first?.pinnedIdentifiers == ["japan", "peru"])
  }
}
