// CoreMemsTests/Services/DecidedPhotosStoreTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Decided photos store")
struct DecidedPhotosStoreTests {
  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("decided-\(UUID().uuidString).json")

  private func makeStore() -> DecidedPhotosStore { DecidedPhotosStore(fileURL: fileURL) }

  @Test func markDecidedAccumulatesIdentifiers() {
    let store = makeStore()

    store.markDecided(["a", "b"])
    store.markDecided(["b", "c"])

    #expect(store.decidedIdentifiers() == ["a", "b", "c"])
  }

  @Test func decidedIdentifiersSurviveReloading() {
    makeStore().markDecided(["a", "b"])

    #expect(makeStore().decidedIdentifiers() == ["a", "b"])
  }

  @Test func clearForgetsEverything() {
    let store = makeStore()
    store.markDecided(["a"])

    store.clear()

    #expect(store.decidedIdentifiers().isEmpty)
  }

  @Test func fileIsAPlainIdentifierArray() throws {
    makeStore().markDecided(["b", "a"])

    let decoded = try JSONDecoder().decode([String].self, from: Data(contentsOf: fileURL))

    #expect(decoded == ["a", "b"])
  }
}
