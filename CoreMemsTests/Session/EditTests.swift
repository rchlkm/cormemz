// CoreMemsTests/Session/EditTests.swift
import Testing

@testable import CoreMems

@Suite("Editing photos")
@MainActor
struct EditTests {
  private var rotation: MediaEdit {
    var edit = MediaEdit()
    edit.rotate()
    return edit
  }

  @Test func savingAnEditStagesItWithoutDecidingThePhoto() async {
    let h = await SessionHarness.started(photoCount: 2)

    let saved = h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    #expect(saved)
    #expect(h.vm.photos[0].edit == rotation)
    #expect(h.vm.photos[0].decision == .undecided)
    #expect(h.vm.currentIndex == 0)
    #expect(h.vm.history.isEmpty)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.markedPhotos.map(\.id) == [SessionHarness.photoID(0)])
  }

  @Test func savingAnEditStartsRenderingIt() async {
    let h = await SessionHarness.started(photoCount: 2)

    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(1))

    #expect(h.library.preparedEdits.map(\.assetID) == [SessionHarness.assetID(1)])
    #expect(h.library.preparedEdits.first?.edit == rotation)
  }

  @Test func savingAnEditThatChangesNothingIsIgnored() async {
    let h = await SessionHarness.started(photoCount: 2)

    let saved = h.vm.saveEdit(MediaEdit(), photoID: SessionHarness.photoID(0))

    #expect(!saved)
    #expect(h.vm.photos[0].edit == nil)
    #expect(h.library.preparedEdits.isEmpty)
  }

  @Test func editingAPhotoMarkedForDeletionKeepsItInstead() async {
    let h = await SessionHarness.started(photoCount: 2)
    await h.decide(0, .pendingDelete)

    let saved = h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    #expect(saved)
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingItems.isEmpty)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
    #expect(h.vm.currentIndex == 1)
  }

  @Test func editingAPhotoMarkedForConversionKeepsItLive() async {
    let h = await SessionHarness.started(photoCount: 2, liveIndexes: [0])
    await h.decide(0, .convertToStill)

    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingConversions.isEmpty)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
  }

  @Test func goingBackAfterEditingAMarkedPhotoMarksItAgain() async {
    let h = await SessionHarness.started(photoCount: 2)
    await h.decide(0, .pendingDelete)
    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    h.vm.goBack()

    #expect(h.vm.photos[0].decision == .pendingDelete)
    #expect(h.vm.pendingEdits.isEmpty)
  }

  @Test func keepingAnEditedPhotoKeepsItsEdit() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    await h.decide(0, .keep)

    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
  }

  @Test func deletingAnEditedPhotoSetsItsEditAsideUntilUndone() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    await h.decide(0, .pendingDelete)
    #expect(h.vm.pendingEdits.isEmpty)
    #expect(h.vm.markedPhotos.map(\.id) == [SessionHarness.photoID(0)])

    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.pendingEdits.map(\.id) == [SessionHarness.photoID(0)])
  }

  @Test func undoingAnEditDiscardsItAndLeavesTheDecision() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))
    await h.decide(0, .keep)

    h.vm.restoreMany(ids: [SessionHarness.photoID(0)])

    #expect(h.vm.photos[0].edit == nil)
    #expect(h.vm.photos[0].decision == .keep)
    #expect(h.vm.markedPhotos.isEmpty)
    #expect(h.haptics.trayRestoreCallCount == 1)
  }

  @Test func editsAreRestoredWithTheSession() async {
    let h = await SessionHarness.started(photoCount: 2)
    h.vm.saveEdit(rotation, photoID: SessionHarness.photoID(0))

    let restored = h.persistence.snapshot?.restoredDeck

    #expect(restored?.photos[0].edit == rotation)
  }
}
