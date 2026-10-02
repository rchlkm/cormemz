// CoreMemsTests/Services/LifetimeStatsTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Lifetime stats")
struct LifetimeStatsTests {
  @Test func keptUnchangedExcludesConversions() {
    let stats = LifetimeSessionStats(totalKept: 10, livePhotosConverted: 3)

    #expect(stats.keptUnchanged == 7)
  }

  @Test func keptUnchangedExcludesEdits() {
    let stats = LifetimeSessionStats(totalKept: 10, livePhotosConverted: 3, mediaEdited: 2)

    #expect(stats.keptUnchanged == 5)
  }

  @Test func recordingASessionAddsItsEdits() {
    var stats = LifetimeSessionStats()

    stats.recordSession(kept: 6, deleted: 2, edited: 3, bytesDeleted: 100)
    stats.recordSession(kept: 1, deleted: 0, edited: 1, bytesDeleted: 0)

    #expect(stats.mediaEdited == 4)
    #expect(stats.totalKept == 7)
    #expect(stats.totalDecided == 9)
    #expect(stats.keptUnchanged == 3)
  }

  @Test func statsSavedWithoutAnEditedCountLoadAsZero() throws {
    let json = Data(#"{"schemaVersion":1,"totalKept":4,"totalDecided":5}"#.utf8)

    let stats = try JSONDecoder().decode(LifetimeSessionStats.self, from: json)

    #expect(stats.mediaEdited == 0)
    #expect(stats.keptUnchanged == 4)
    #expect(stats.schemaVersion == 1)
  }

  @Test func keptUnchangedNeverGoesNegative() {
    let stats = LifetimeSessionStats(totalKept: 2, livePhotosConverted: 5)

    #expect(stats.keptUnchanged == 0)
  }

  @Test func progressIsTheDecidedShareOfTheLibrary() {
    #expect(BrowseProgressCard.fraction(decided: 25, total: 100) == 0.25)
  }

  @Test func progressIsZeroForAnEmptyLibrary() {
    #expect(BrowseProgressCard.fraction(decided: 5, total: 0) == 0)
  }

  @Test func progressNeverExceedsTheWholeLibrary() {
    #expect(BrowseProgressCard.fraction(decided: 150, total: 100) == 1)
  }
}
