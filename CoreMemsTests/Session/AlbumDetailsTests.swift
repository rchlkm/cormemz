// CoreMemsTests/Session/AlbumDetailsTests.swift
import Testing

@testable import CoreMems

@Suite("Album details")
@MainActor
struct AlbumDetailsTests {
  private let ref = AlbumRef.existing(localIdentifier: "a")

  @Test func countLabelCountsItemsAndSingularizes() {
    #expect(AlbumOption(ref: ref, name: "A", assetCount: 15).countLabel == "15 items")
    #expect(AlbumOption(ref: ref, name: "A", assetCount: 1).countLabel == "1 item")
    #expect(AlbumOption(ref: ref, name: "A").countLabel == nil)
  }

  @Test func contentsAreReadOncePerLibrarySnapshot() async {
    let library = RecordingPhotoLibrary()
    let first = AlbumContents(photoCount: 12, videoCount: 3, bytes: 1_000)
    let second = AlbumContents(photoCount: 13, videoCount: 3, bytes: 2_000)
    library.albumContents = ["a": first]
    let vm = SessionHarness(library: library).vm

    #expect(await vm.albumContents(of: ref) == first)
    library.albumContents["a"] = second
    #expect(await vm.albumContents(of: ref) == first)

    await vm.refreshLibraryAlbums()
    #expect(await vm.albumContents(of: ref) == second)
  }
}
