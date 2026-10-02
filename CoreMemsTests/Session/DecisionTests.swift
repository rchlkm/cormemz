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
    h.vm.goBack()

    #expect(competing == nil)
    #expect(h.vm.photos[1].decision == .undecided)
    #expect(h.haptics.goBackCallCount == 0)

    await task?.value
    #expect(h.vm.history.count == 1)
  }

  @Test func savingAnEditShowsTheMarkThenRecordsItAsEdited() async {
    let h = await SessionHarness.started(photoCount: 2)
    var edit = MediaEdit()
    edit.rotate()

    let task = h.vm.saveEdit(edit, photoID: SessionHarness.photoID(0))

    #expect(h.vm.markingDecision == .edited)
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.haptics.keepCallCount == 1)

    await task?.value

    #expect(h.vm.markingDecision == nil)
    #expect(h.vm.photos[0].decision == .edited)
    #expect(h.vm.photos[0].edit == edit)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.currentIndex == 1)
  }

  @Test func applyingASessionRecordsItsEditsInTheStats() async {
    let h = await SessionHarness.started(photoCount: 2)
    var edit = MediaEdit()
    edit.rotate()
    await h.vm.saveEdit(edit, photoID: SessionHarness.photoID(0))?.value
    await h.decide(1, .keep)

    await h.vm.applyChanges()

    #expect(h.vm.editedCount == 1)
    #expect(h.stats.stats.mediaEdited == 1)
    #expect(h.stats.stats.totalKept == 2)
    #expect(h.stats.stats.keptUnchanged == 1)
  }

  @Test func savingAnEditThatChangesNothingIsIgnored() async {
    let h = await SessionHarness.started(photoCount: 2)

    let task = h.vm.saveEdit(MediaEdit(), photoID: SessionHarness.photoID(0))

    #expect(task == nil)
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.vm.photos[0].edit == nil)
    #expect(h.vm.history.isEmpty)
  }

  @Test func savingAnEditWhileAMarkIsShowingIsIgnored() async {
    let h = await SessionHarness.started(photoCount: 3, liveIndexes: [0])
    let task = h.vm.decide(index: 0, decision: .convertToStill)
    var edit = MediaEdit()
    edit.rotate()

    let competing = h.vm.saveEdit(edit, photoID: SessionHarness.photoID(1))

    #expect(competing == nil)
    #expect(h.vm.photos[1].edit == nil)
    await task?.value
  }

  @Test func decidingTheLastPhotoOpensPendingChanges() async {
    let h = await SessionHarness.started(photoCount: 2)

    await h.decide(0, .keep)
    #expect(h.vm.screen == .browse)
    await h.decide(1, .pendingDelete)

    #expect(h.vm.screen == .pendingChanges)
  }
}
