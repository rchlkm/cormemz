// CoreMemsTests/Views/EditToolTests.swift
import Testing

@testable import CoreMems

@Suite("Edit tools")
struct EditToolTests {
  @Test func aPhotoOffersOnlyCrop() {
    #expect(EditTool.available(for: .unavailable) == [.crop])
  }

  @Test func aTrimmableVideoOffersTrimThenCrop() {
    #expect(EditTool.available(for: .supported(duration: 12)) == [.trim, .crop])
  }

  @Test func aSlowMotionVideoStillShowsTrim() {
    #expect(EditTool.available(for: .unsupported) == [.trim, .crop])
  }

  @Test func trimIsDisabledWithAReasonForSlowMotion() {
    #expect(EditTool.trim.disabledNotice(for: .unsupported) != nil)
    #expect(EditTool.trim.disabledNotice(for: .supported(duration: 12)) == nil)
    #expect(EditTool.crop.disabledNotice(for: .unsupported) == nil)
  }

  @Test func theEditorOpensOnTheFirstUsableTool() {
    #expect(EditTool.initial(for: .supported(duration: 12)) == .trim)
    #expect(EditTool.initial(for: .unsupported) == .crop)
    #expect(EditTool.initial(for: .unavailable) == .crop)
  }
}
