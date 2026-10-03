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

  @Test func totalDecidedIsAlwaysKeptPlusDeleted() {
    var stats = LifetimeSessionStats()

    stats.recordSession(kept: 3, deleted: 2, bytesDeleted: 0)
    stats.recordSession(kept: 1, deleted: 4, bytesDeleted: 0)

    #expect(stats.totalDecided == stats.totalKept + stats.totalDeleted)
    #expect(stats.totalDecided == 10)
  }

  @Test func aStrayTotalDecidedKeyOnDiskIsIgnoredInFavorOfTheDerivedSum() throws {
    // Guards against the exact corruption this once caused: an old file with a
    // stale standalone "totalDecided" value must not override totalKept + totalDeleted.
    let json = Data(#"{"totalDecided": 69, "totalKept": 2137, "totalDeleted": 1058}"#.utf8)

    let stats = try JSONDecoder().decode(LifetimeSessionStats.self, from: json)

    #expect(stats.totalDecided == 3195)
  }

  @Test func savedStatsRecordTheCurrentSchemaVersion() throws {
    let data = try JSONEncoder().encode(LifetimeSessionStats(totalKept: 4))

    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(object?["schemaVersion"] as? Int == LifetimeSessionStats.currentSchemaVersion)
  }

  @Test func unversionedStatsLoadAsTheCurrentSchemaVersion() throws {
    let json = Data(#"{"totalKept": 7, "totalDeleted": 3}"#.utf8)

    let stats = try JSONDecoder().decode(LifetimeSessionStats.self, from: json)

    #expect(stats.schemaVersion == LifetimeSessionStats.currentSchemaVersion)
    #expect(stats.totalKept == 7)
    #expect(stats.totalDeleted == 3)
  }

  @Test func keptUnchangedNeverGoesNegative() {
    let stats = LifetimeSessionStats(totalKept: 2, livePhotosConverted: 5)

    #expect(stats.keptUnchanged == 0)
  }

  @Test func progressIsTheKeptShareOfTheLibrary() {
    #expect(BrowseProgressCard.fraction(kept: 25, total: 100) == 0.25)
  }

  @Test func progressIsZeroForAnEmptyLibrary() {
    #expect(BrowseProgressCard.fraction(kept: 5, total: 0) == 0)
  }

  @Test func progressNeverExceedsTheWholeLibrary() {
    #expect(BrowseProgressCard.fraction(kept: 150, total: 100) == 1)
  }
}
