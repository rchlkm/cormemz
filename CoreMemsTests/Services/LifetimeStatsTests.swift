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

  @Test func progressIsTheReviewedShareOfTheLibrary() {
    #expect(ReviewProgressCard.fraction(reviewed: 25, total: 100) == 0.25)
  }

  @Test func progressIsZeroForAnEmptyLibrary() {
    #expect(ReviewProgressCard.fraction(reviewed: 5, total: 0) == 0)
  }

  @Test func progressNeverExceedsTheWholeLibrary() {
    #expect(ReviewProgressCard.fraction(reviewed: 150, total: 100) == 1)
  }
}
