// CoreMemsTests/Session/MediaEditTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Media edits")
struct MediaEditTests {
  @Test func aNewEditChangesNothing() {
    let edit = MediaEdit()

    #expect(edit.isEmpty)
    #expect(edit.quarterTurns == 0)
    #expect(edit.trimRange == nil)
    #expect(edit.deletesOriginal)
  }

  @Test func rotatingFourTimesComesBackToUnrotated() {
    var edit = MediaEdit()

    edit.rotate()
    #expect(edit.quarterTurns == 1)
    #expect(!edit.isEmpty)

    edit.rotate()
    edit.rotate()
    edit.rotate()
    #expect(edit.quarterTurns == 0)
    #expect(edit.isEmpty)
  }

  @Test func aTrimAloneIsAnEdit() {
    var edit = MediaEdit()
    edit.trimRange = 1.5...4

    #expect(!edit.isEmpty)
  }

  @Test func trimmingKeepsTheChosenPart() {
    var edit = MediaEdit()

    edit.trim(to: 2...8, ofDuration: 10)

    #expect(edit.trimRange == 2...8)
    #expect(!edit.isEmpty)
  }

  @Test func trimmingToTheWholeVideoClearsTheTrimAndItsOptions() {
    var edit = MediaEdit()
    edit.trim(to: 2...8, ofDuration: 10)
    edit.deletesOriginal = false

    edit.trim(to: 0...10, ofDuration: 10)

    #expect(edit.trimRange == nil)
    #expect(edit.deletesOriginal)
    #expect(edit.isEmpty)
  }

  @Test func trimmingOnlyOneEndIsStillATrim() {
    var edit = MediaEdit()

    edit.trim(to: 0...6, ofDuration: 10)

    #expect(edit.trimRange == 0...6)
  }

  @Test func anEditRoundTripsThroughJSON() throws {
    var edit = MediaEdit()
    edit.rotate()
    edit.trimRange = 0.5...3
    edit.deletesOriginal = false

    let decoded = try JSONDecoder().decode(MediaEdit.self, from: JSONEncoder().encode(edit))

    #expect(decoded == edit)
  }

  @Test func aNewEditHasNoCrop() {
    let edit = MediaEdit()

    #expect(edit.displayedCropRect == .wholeImage)
    #expect(!edit.changesPixels)
  }

  @Test func aCropAloneIsAnEdit() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0, width: 0.5, height: 1)

    #expect(!edit.isEmpty)
    #expect(edit.changesPixels)
  }

  @Test func cropRectHoldsTheSameAreaAtEveryTurn() {
    // The left half of the upright source, then where each turn displays it.
    let leftHalf = CGRect(x: 0, y: 0, width: 0.5, height: 1)
    let shown = [
      leftHalf,
      CGRect(x: 0, y: 0.5, width: 1, height: 0.5),
      CGRect(x: 0.5, y: 0, width: 0.5, height: 1),
      CGRect(x: 0, y: 0, width: 1, height: 0.5),
    ]
    var edit = MediaEdit()
    edit.displayedCropRect = leftHalf

    for turns in 0..<4 {
      #expect(edit.displayedCropRect == shown[turns])
      #expect(edit.cropRect == leftHalf)
      edit.rotate()
    }
  }

  @Test func aDisplayedCropIsStoredInTheUprightSource() {
    var edit = MediaEdit()
    edit.rotate()

    edit.displayedCropRect = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)

    #expect(edit.cropRect == CGRect(x: 0, y: 0, width: 0.5, height: 1))
  }

  @Test func cropToTheWholeImageClearsTheCrop() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0, width: 0.5, height: 1)

    edit.displayedCropRect = .wholeImage

    #expect(edit.cropRect == nil)
    #expect(edit.isEmpty)
  }

  @Test func cropToAnAspectUsesTheRotatedShape() {
    var edit = MediaEdit()
    edit.rotate()

    edit.crop(to: .square, ofSourceSize: CGSize(width: 4, height: 2))

    // Shown 2 wide and 4 tall, the square is the middle of the height.
    #expect(edit.displayedCropRect == CGRect(x: 0, y: 0.25, width: 1, height: 0.5))
    #expect(edit.cropRect == CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
  }

  @Test func cropToOriginalClearsTheCrop() {
    var edit = MediaEdit()
    edit.crop(to: .square, ofSourceSize: CGSize(width: 4, height: 2))

    edit.crop(to: .original, ofSourceSize: CGSize(width: 4, height: 2))

    #expect(edit.cropRect == nil)
  }

  @Test func aCropRoundTripsThroughJSON() throws {
    var edit = MediaEdit()
    edit.rotate()
    edit.crop(to: .fourThree, ofSourceSize: CGSize(width: 4000, height: 3000))

    let decoded = try JSONDecoder().decode(MediaEdit.self, from: JSONEncoder().encode(edit))

    #expect(decoded == edit)
  }

  @Test func anEditSavedWithoutACropStillDecodes() throws {
    let saved = Data(#"{"quarterTurns":1,"trimRange":[0.5,3],"deletesOriginal":false}"#.utf8)

    let decoded = try JSONDecoder().decode(MediaEdit.self, from: saved)

    #expect(decoded.quarterTurns == 1)
    #expect(decoded.trimRange == 0.5...3)
    #expect(!decoded.deletesOriginal)
    #expect(decoded.cropRect == nil)
  }

  @Test func anEditSavedWithOnlyDefaultsStillDecodes() throws {
    let decoded = try JSONDecoder().decode(MediaEdit.self, from: Data("{}".utf8))

    #expect(decoded == MediaEdit())
  }

  @Test func theSummaryNamesTheCrop() {
    var edit = MediaEdit()
    edit.rotate()
    edit.crop(to: .square, ofSourceSize: CGSize(width: 4, height: 2))

    #expect(edit.summary == "Rotated 90°, Cropped")
  }
}
