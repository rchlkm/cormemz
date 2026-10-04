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
}
