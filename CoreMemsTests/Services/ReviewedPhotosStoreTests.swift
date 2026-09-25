// CoreMemsTests/Services/ReviewedPhotosStoreTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Reviewed photos store")
struct ReviewedPhotosStoreTests {
  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("reviewed-\(UUID().uuidString).json")

  private func makeStore() -> ReviewedPhotosStore { ReviewedPhotosStore(fileURL: fileURL) }

  @Test func markReviewedAccumulatesIdentifiers() {
    let store = makeStore()

    store.markReviewed(["a", "b"])
    store.markReviewed(["b", "c"])

    #expect(store.reviewedIdentifiers() == ["a", "b", "c"])
  }

  @Test func reviewedIdentifiersSurviveReloading() {
    makeStore().markReviewed(["a", "b"])

    #expect(makeStore().reviewedIdentifiers() == ["a", "b"])
  }

  @Test func clearForgetsEverything() {
    let store = makeStore()
    store.markReviewed(["a"])

    store.clear()

    #expect(store.reviewedIdentifiers().isEmpty)
  }

  @Test func fileIsAPlainIdentifierArray() throws {
    makeStore().markReviewed(["b", "a"])

    let decoded = try JSONDecoder().decode([String].self, from: Data(contentsOf: fileURL))

    #expect(decoded == ["a", "b"])
  }
}
