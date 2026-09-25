// CoreMemsTests/Session/GoBackTests.swift
import Testing

@testable import CoreMems

@Suite("Going back")
@MainActor
struct GoBackTests {
  @Test func goBackStepsBackAndKeepsTheDecision() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)

    h.vm.goBack()

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canGoBack == false)
    #expect(h.haptics.goBackCallCount == 1)
  }

  @Test func goBackWithNoHistoryDoesNothing() async {
    let h = await SessionHarness.started(photoCount: 3)

    h.vm.goBack()

    #expect(h.vm.currentIndex == 0)
    #expect(h.haptics.goBackCallCount == 0)
  }

  @Test func repeatedGoBackStepsBackThroughDecisionsNewestFirst() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .keep)
    await h.decide(1, .pendingDelete)

    h.vm.goBack()
    #expect(h.vm.photos[1].decision == .pendingDelete)
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.currentIndex == 1)

    h.vm.goBack()
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func goBackStepsOntoAConversionAndKeepsItMarked() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)

    h.vm.goBack()

    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.pendingConversions.count == 1)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.canGoBack == false)
  }

  @Test func keepingAfterSteppingBackCancelsTheConversion() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.goBack()

    await h.decide(0, .keep)

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingConversions.isEmpty)
    #expect(h.vm.currentIndex == 1)
  }

  @Test func goingBackAfterChangingADecisionKeepsTheNewDecision() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.goBack()
    await h.decide(0, .keep)

    h.vm.goBack()

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.currentIndex == 0)
  }

  @Test func convertingAgainAfterSteppingBackMovesOnUnchanged() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)
    h.vm.goBack()

    await h.decide(0, .convertToStill)

    #expect(h.vm.photos[0].decision == .convertToStill)
    #expect(h.vm.pendingConversions.count == 1)
    #expect(h.vm.currentIndex == 1)
  }

  @Test func goingBackOverATrayRestoreKeepsTheReviewIndex() async {
    let h = await SessionHarness.started(photoCount: 3)
    await h.decide(0, .pendingDelete)
    await h.decide(1, .keep)
    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    h.vm.goBack()

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.vm.currentIndex == 2)
  }

  @Test func goBackIsUnavailableOnceHistoryIsEmpty() async {
    let h = await SessionHarness.started(photoCount: 2)
    #expect(h.vm.canGoBack == false)

    await h.decide(0, .keep)
    #expect(h.vm.canGoBack)
  }
}
