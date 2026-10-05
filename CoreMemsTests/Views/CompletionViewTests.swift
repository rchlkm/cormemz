// CoreMemsTests/Views/CompletionViewTests.swift
import Testing

@testable import CoreMems

@Suite("Completion screen")
struct CompletionViewTests {
  private func tileLabels(
    kept: Int = 0, deleted: Int = 0, converted: Int = 0, edited: Int = 0, albums: Int = 0
  ) -> [String] {
    CompletionView(
      keptCount: kept + converted,
      deletedCount: deleted,
      albumAssignedCount: albums,
      missingAlbumCount: 0,
      convertedCount: converted,
      editedCount: edited,
      failedEdits: [],
      onRetryEdits: { _ in [:] },
      onDiscardEdit: { _ in },
      deletedBytes: 0,
      convertedBytesSaved: 0,
      trimmedBytesSaved: 0,
      keptPhotoCount: 0,
      libraryPhotoCount: 0,
      onAgain: {}
    ).tiles.map(\.label)
  }

  @Test func tilesCoverEveryOutcomeThatHappened() {
    #expect(
      tileLabels(kept: 4, deleted: 2, converted: 1, edited: 3, albums: 5)
        == ["Kept", "Deleted", "Converted to stills", "Edited", "Added to albums"])
  }

  @Test func tilesLeaveOutOutcomesWithNoPhotos() {
    #expect(tileLabels(kept: 4) == ["Kept"])
    #expect(tileLabels(deleted: 2, edited: 1) == ["Deleted", "Edited"])
  }

  @Test func convertedPhotosGetTheirOwnTileInsteadOfCountingAsKept() {
    #expect(tileLabels(converted: 2) == ["Converted to stills"])
  }

  @Test func aSessionWithNoOutcomesStillShowsTheKeptTile() {
    #expect(tileLabels() == ["Kept"])
  }
}
