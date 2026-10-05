// CoreMemsTests/Views/OutcomeRatioCardTests.swift
import Testing

@testable import CoreMems

@Suite("Outcome ratio card")
struct OutcomeRatioCardTests {
  private func legendLabels(kept: Int, converted: Int, deleted: Int) -> [String] {
    OutcomeRatioCard(kept: kept, converted: converted, deleted: deleted).legendSegments.map(\.label)
  }

  @Test func theLegendListsEveryOutcomeThatHappened() {
    #expect(legendLabels(kept: 5, converted: 2, deleted: 3) == ["Kept", "Converted", "Deleted"])
  }

  @Test func theLegendLeavesOutOutcomesWithNoPhotos() {
    #expect(legendLabels(kept: 5, converted: 0, deleted: 0) == ["Kept"])
    #expect(legendLabels(kept: 0, converted: 2, deleted: 3) == ["Converted", "Deleted"])
  }

  @Test func theLegendListsEveryOutcomeWhenNothingHappened() {
    #expect(legendLabels(kept: 0, converted: 0, deleted: 0) == ["Kept", "Converted", "Deleted"])
  }
}
