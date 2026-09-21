// CoreMemsTests/Session/RefreshTests.swift
import Testing

@testable import CoreMems

@Suite("Refreshing the library")
@MainActor
struct RefreshTests {
  @Test func refreshReadsTheAlbumListAndPhotoCount() async {
    let h = await SessionHarness.started(photoCount: 3)
    h.vm.eligiblePhotoCount = 0
    #expect(h.vm.libraryAlbums == nil)

    await h.vm.refreshLibrary()

    #expect(h.vm.libraryAlbums != nil)
    #expect(h.vm.eligiblePhotoCount == 3)
  }
}
