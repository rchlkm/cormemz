// CoreMemsTests/Session/DecisionTests.swift
import Testing

@testable import CoreMems

@Suite("Deciding on photos")
@MainActor
struct DecisionTests {
  @Test func keepRecordsDecisionAndAdvances() async {
    let h = await SessionHarness.started(photoCount: 3)

    await h.decide(0, .keep)

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.currentIndex == 1)
    #expect(h.vm.history.count == 1)
    #expect(h.haptics.keepCallCount == 1)
  }

  @Test func deleteMarksPhotoForDeletionAndAdvances() async {
    let h = await SessionHarness.started(photoCount: 3)

    await h.decide(0, .pendingDelete)

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.vm.pendingItems.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.currentIndex == 1)
    #expect(h.haptics.markForDeletionCallCount == 1)
  }

  @Test func decidingAnotherPhotoLeavesTheCurrentCardInPlace() async {
    let h = await SessionHarness.started(photoCount: 3)

    await h.decide(2, .keep)

    #expect(h.vm.photos[2].decision == .keep)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.history.first?.advancedIndex == false)
  }

  @Test func outOfRangeIndexIsIgnored() async {
    let h = await SessionHarness.started(photoCount: 2)

    let task = h.vm.decide(index: 5, decision: .keep)

    #expect(task == nil)
    #expect(h.vm.history.isEmpty)
    #expect(h.haptics.keepCallCount == 0)
  }

  @Test func convertToStillIsIgnoredForANonLivePhoto() async {
    let h = await SessionHarness.started(photoCount: 2)

    let task = h.vm.decide(index: 0, decision: .convertToStill)

    #expect(task == nil)
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.vm.history.isEmpty)
    #expect(h.haptics.convertToStillCallCount == 0)
  }

  @Test func convertToStillShowsTheMarkBeforeRecordingIt() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])

    let task = h.vm.decide(index: 0, decision: .convertToStill)

    #expect(h.vm.markingDecision == .convertToStill)
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.haptics.convertToStillCallCount == 1)

    await task?.value

    #expect(h.vm.markingDecision == nil)
    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.currentIndex == 1)
  }

  @Test func decisionsAreIgnoredWhileAMarkIsShowing() async {
    let h = await SessionHarness.started(photoCount: 3, liveIndexes: [0])
    let task = h.vm.decide(index: 0, decision: .convertToStill)

    let competing = h.vm.decide(index: 1, decision: .keep)
    h.vm.quickUndo()

    #expect(competing == nil)
    #expect(h.vm.photos[1].decision == .undecided)
    #expect(h.haptics.undoCallCount == 0)

    await task?.value
    #expect(h.vm.history.count == 1)
  }

  @Test func decidingTheLastPhotoOpensPendingReview() async {
    let h = await SessionHarness.started(photoCount: 2)

    await h.decide(0, .keep)
    #expect(h.vm.screen == .review)
    await h.decide(1, .pendingDelete)

    #expect(h.vm.screen == .pendingReview)
  }
}
