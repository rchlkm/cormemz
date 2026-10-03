// CoreMemsTests/Services/KeptPhotosStoreTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Kept photos store")
struct KeptPhotosStoreTests {
  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("kept-\(UUID().uuidString).json")

  private func makeStore() -> KeptPhotosStore { KeptPhotosStore(fileURL: fileURL) }

  @Test func markKeptAccumulatesIdentifiers() {
    let store = makeStore()

    store.markKept(["a", "b"])
    store.markKept(["b", "c"])

    #expect(store.keptIdentifiers() == ["a", "b", "c"])
  }

  @Test func keptIdentifiersSurviveReloading() {
    makeStore().markKept(["a", "b"])

    #expect(makeStore().keptIdentifiers() == ["a", "b"])
  }

  @Test func clearForgetsEverything() {
    let store = makeStore()
    store.markKept(["a"])

    store.clear()

    #expect(store.keptIdentifiers().isEmpty)
  }

  @Test func aLegacyDecidedPhotosFileMigratesToTheNewName() throws {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    let legacyURL = dir.appendingPathComponent("core-mems-decided-photos.json")
    let newURL = dir.appendingPathComponent("core-mems-kept-photos.json")
    try? FileManager.default.removeItem(at: legacyURL)
    try? FileManager.default.removeItem(at: newURL)
    try JSONEncoder().encode(["legacy-id"]).write(to: legacyURL)
    defer {
      try? FileManager.default.removeItem(at: legacyURL)
      try? FileManager.default.removeItem(at: newURL)
    }

    let store = KeptPhotosStore()

    #expect(store.keptIdentifiers() == ["legacy-id"])
    #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
  }

  @Test func fileIsAPlainIdentifierArray() throws {
    makeStore().markKept(["b", "a"])

    let decoded = try JSONDecoder().decode([String].self, from: Data(contentsOf: fileURL))

    #expect(decoded == ["a", "b"])
  }
}
