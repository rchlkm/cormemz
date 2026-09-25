// CoreMemsTests/Session/AlbumCatalogTests.swift
import Testing

@testable import CoreMems

@Suite("Album catalog")
struct AlbumCatalogTests {
  private func option(_ id: String) -> AlbumOption {
    AlbumOption(ref: .existing(localIdentifier: id), name: id)
  }

  @Test func aNewCatalogIsNotLoaded() {
    let catalog = AlbumCatalog()

    #expect(!catalog.isLoaded)
    #expect(catalog.albums(withIdentifiers: ["a"]).isEmpty)
  }

  @Test func loadedAlbumsAreResolvedInTheRequestedOrder() {
    var catalog = AlbumCatalog()
    catalog.albums = [option("a"), option("b"), option("c")]

    #expect(catalog.isLoaded)
    #expect(catalog.albums(withIdentifiers: ["c", "a"]).map(\.name) == ["c", "a"])
  }

  @Test func unknownIdentifiersAreSkipped() {
    var catalog = AlbumCatalog()
    catalog.albums = [option("a")]

    #expect(catalog.albums(withIdentifiers: ["missing", "a"]).map(\.name) == ["a"])
  }

  @Test func reloadingReplacesTheIndex() {
    var catalog = AlbumCatalog()
    catalog.albums = [option("a")]

    catalog.albums = [option("b")]

    #expect(catalog.albums(withIdentifiers: ["a"]).isEmpty)
    #expect(catalog.albums(withIdentifiers: ["b"]).map(\.name) == ["b"])
  }

  @Test func clearingTheAlbumsUnloadsTheCatalog() {
    var catalog = AlbumCatalog()
    catalog.albums = [option("a")]

    catalog.albums = nil

    #expect(!catalog.isLoaded)
    #expect(catalog.albums(withIdentifiers: ["a"]).isEmpty)
  }
}
