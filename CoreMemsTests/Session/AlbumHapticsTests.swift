// CoreMemsTests/Session/AlbumHapticsTests.swift
import Testing

@testable import CoreMems

@Suite("Album selection feedback")
@MainActor
struct AlbumHapticsTests {
  private let album = AlbumRef.existing(localIdentifier: "album-1")

  @Test func turningAnAlbumOnGivesHapticFeedback() async {
    let h = await SessionHarness.started(photoCount: 2)
    let photoID = h.vm.photos[0].id

    h.vm.toggleAlbumMembership(photoID: photoID, ref: album)

    #expect(h.haptics.albumToggleCount == 1)
  }

  @Test func turningAnAlbumOffGivesHapticFeedback() async {
    let h = await SessionHarness.started(photoCount: 2)
    let photoID = h.vm.photos[0].id
    h.vm.toggleAlbumMembership(photoID: photoID, ref: album)

    h.vm.toggleAlbumMembership(photoID: photoID, ref: album)

    #expect(h.haptics.albumToggleCount == 2)
  }
}
