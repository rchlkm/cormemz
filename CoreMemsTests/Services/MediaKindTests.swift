// CoreMemsTests/Services/MediaKindTests.swift
import Photos
import Testing

@testable import CoreMems

@Suite("Media kind")
struct MediaKindTests {
  @Test func eachSubtypeMapsToItsKind() {
    #expect(MediaKind(subtypes: .videoHighFrameRate) == .slowMo)
    #expect(MediaKind(subtypes: .videoTimelapse) == .timelapse)
    #expect(MediaKind(subtypes: .videoCinematic) == .cinematic)
    #expect(MediaKind(subtypes: .photoPanorama) == .panorama)
  }

  @Test func ordinaryAndUnbadgedSubtypesHaveNoKind() {
    #expect(MediaKind(subtypes: []) == nil)
    #expect(MediaKind(subtypes: .photoScreenshot) == nil)
    #expect(MediaKind(subtypes: .photoLive) == nil)
  }

  @Test func eachKindHasADistinctTitleAndSymbol() {
    #expect(Set(MediaKind.allCases.map(\.title)).count == MediaKind.allCases.count)
    #expect(Set(MediaKind.allCases.map(\.symbol)).count == MediaKind.allCases.count)
  }
}
