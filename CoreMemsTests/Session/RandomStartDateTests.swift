// CoreMemsTests/Session/RandomStartDateTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Random start date")
@MainActor
struct RandomStartDateTests {
  @Test func returnsTheLibrarysRandomAssetDate() async {
    let library = RecordingPhotoLibrary()
    let anchor = Date(timeIntervalSince1970: 1_600_000_000)
    library.stubbedRandomDate = anchor
    let harness = SessionHarness(library: library)

    #expect(await harness.vm.randomAssetDate() == anchor)
  }

  @Test func isNilForAnEmptyLibrary() async {
    let harness = SessionHarness(library: RecordingPhotoLibrary())

    #expect(await harness.vm.randomAssetDate() == nil)
  }
}
