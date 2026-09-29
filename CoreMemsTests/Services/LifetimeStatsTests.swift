// CoreMemsTests/Services/LifetimeStatsTests.swift
import Testing

@testable import CoreMems

@Suite("Lifetime stats")
struct LifetimeStatsTests {
  @Test func keptUnchangedExcludesConversions() {
    let stats = LifetimeSessionStats(totalKept: 10, livePhotosConverted: 3)

    #expect(stats.keptUnchanged == 7)
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
