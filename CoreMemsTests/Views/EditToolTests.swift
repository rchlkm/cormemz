// CoreMemsTests/Views/EditToolTests.swift
import CoreGraphics
import Testing

@testable import CoreMems

@Suite("Edit tools")
struct EditToolTests {
  private let photo = EditSupport(stillSize: CGSize(width: 4, height: 3))
  private let video = EditSupport(trim: .supported(duration: 12))
  private let slowMotion = EditSupport(trim: .unsupported)

  @Test func aPhotoOffersOnlyCrop() {
    #expect(EditTool.available(for: photo) == [.crop])
  }

  @Test func aTrimmableVideoOffersTrimThenCrop() {
    #expect(EditTool.available(for: video) == [.trim, .crop])
  }

  @Test func aSlowMotionVideoStillShowsTrim() {
    #expect(EditTool.available(for: slowMotion) == [.trim, .crop])
  }

  @Test func trimIsDisabledWithAReasonForSlowMotion() {
    #expect(EditTool.trim.disabledNotice(for: slowMotion) != nil)
    #expect(EditTool.trim.disabledNotice(for: video) == nil)
    #expect(EditTool.crop.disabledNotice(for: slowMotion) == nil)
  }

  @Test func theEditorOpensOnTheFirstUsableTool() {
    #expect(EditTool.initial(for: video) == .trim)
    #expect(EditTool.initial(for: slowMotion) == .crop)
    #expect(EditTool.initial(for: photo) == .crop)
  }

  @Test func onlyAStillPhotoCanBeCropped() {
    #expect(photo.cropNotice == nil)
    #expect(video.cropNotice != nil)
    #expect(EditSupport().cropNotice != nil)
  }
}
