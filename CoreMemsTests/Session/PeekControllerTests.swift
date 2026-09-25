// CoreMemsTests/Session/PeekControllerTests.swift
import Testing

@testable import CoreMems

@Suite("Peek controller")
@MainActor
struct PeekControllerTests {
  private func photo(_ id: String) -> SessionPhoto {
    SessionPhoto(id: id, assetIdentifier: "asset-\(id)", previewURL: nil)
  }

  private func settle(_ controller: PeekController) async {
    while controller.state?.isLoading == true { await Task.yield() }
  }

  @Test func beginningLoadsTheNeighborsAroundTheAnchor() async {
    let controller = PeekController()
    controller.loadNeighbors = { anchor, _, _ in [self.photo("a"), self.photo(anchor), self.photo("b")] }

    controller.begin(anchorID: "p1")
    await settle(controller)

    #expect(controller.isPeeking)
    #expect(controller.state?.neighborIDs == ["a", "p1", "b"])
  }

  @Test func endingClearsTheState() {
    let controller = PeekController()
    controller.begin(anchorID: "p1")

    controller.end()

    #expect(!controller.isPeeking)
    #expect(!controller.isNeighbor("other"))
  }

  @Test func onlyPhotosOtherThanTheAnchorAreNeighbors() {
    let controller = PeekController()
    controller.begin(anchorID: "p1")

    #expect(!controller.isNeighbor("p1"))
    #expect(controller.isNeighbor("p2"))
  }

  @Test func cachedNeighborsAreFoundByIDAndTakenOnce() {
    let controller = PeekController()
    controller.cache(photo("n1"), forAssetID: "asset-n1")

    #expect(controller.cachedPhoto(forAssetID: "asset-n1")?.id == "n1")
    #expect(controller.photo(withID: "n1") != nil)
    #expect(controller.take(photoID: "n1")?.id == "n1")
    #expect(controller.photo(withID: "n1") == nil)
    #expect(controller.take(photoID: "n1") == nil)
  }

  @Test func favoritesApplyOnlyToCachedNeighbors() {
    let controller = PeekController()
    controller.cache(photo("n1"), forAssetID: "asset-n1")

    #expect(controller.setFavorite(true, photoID: "n1"))
    #expect(controller.photo(withID: "n1")?.isFavorite == true)
    #expect(!controller.setFavorite(true, photoID: "missing"))
  }
}
