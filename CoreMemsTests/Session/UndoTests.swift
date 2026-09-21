// CoreMemsTests/Session/UndoTests.swift
import Testing

@testable import CoreMems

@Suite("Undoing decisions")
@MainActor
struct UndoTests {
  @Test func undoRevertsTheLastDecisionAndStepsBack() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)

    h.vm.quickUndo()

    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canUndo == false)
    #expect(h.haptics.undoCallCount == 1)
  }

  @Test func undoWithNoHistoryDoesNothing() async {
    let h = await SessionHarness.started(photoCount: 3)

    h.vm.quickUndo()

    #expect(h.vm.currentIndex == 0)
    #expect(h.haptics.undoCallCount == 0)
  }

  @Test func repeatedUndoUnwindsDecisionsNewestFirst() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    h.vm.quickUndo()
    #expect(h.vm.photos[1].decision == .undecided)
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.currentIndex == 1)

    h.vm.quickUndo()
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func undoStepsBackOntoAConversionAndKeepsItMarked() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)

    h.vm.quickUndo()

    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.pendingConversions.count == 1)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canUndo == false)
  }

  @Test func keepingAfterSteppingBackCancelsTheConversion() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.quickUndo()

    await h.decide(0, .keep)

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingConversions.isEmpty)
    #expect(h.vm.currentIndex == 1)
  }

  @Test func undoingAChangedDecisionRestoresTheConversion() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.quickUndo()
    await h.decide(0, .keep)

    h.vm.quickUndo()

    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func convertingAgainAfterSteppingBackMovesOnUnchanged() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.quickUndo()

    await h.decide(0, .convertToStill)

    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.pendingConversions.count == 1)
    #expect(h.vm.currentIndex == 1)
  }

  @Test func undoingATrayRestoreKeepsTheReviewIndex() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)
    await h.decide(1, .keep)
    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    h.vm.quickUndo()

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.vm.currentIndex == 2)
  }

  @Test func undoIsUnavailableOnceHistoryIsEmpty() async {
    let h = await SessionHarness.started(photoCount: 2)
    #expect(h.vm.canUndo == false)

    await h.decide(0, .keep)
    #expect(h.vm.canUndo)
  }
}
