// CoreMemsTests/Services/SessionPersistenceTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Session persistence")
@MainActor
final class SessionPersistenceTests {
  private static let debounce: TimeInterval = 0.05
  private static let settleTime: Duration = .milliseconds(300)

  private let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("session-\(UUID().uuidString).json")
  private let persistence: SessionPersistence

  init() {
    persistence = SessionPersistence(debounceInterval: Self.debounce, fileURL: fileURL)
  }

  deinit {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private static func snapshot(index: Int) -> PersistedSessionSnapshot {
    PersistedSessionSnapshot(
      photoIDs: ["a", "b"], decisions: ["undecided", "undecided"],
      assetIdentifiers: ["asset-a", "asset-b"], currentIndex: index,
      historyPhotoIndices: [], historyPrevious: [], historyNew: [], historyAdvanced: [])
  }

  /// Runs `action`, then waits for the next write to land on disk.
  private func waitForWrite(after action: () -> Void) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      var resumed = false
      persistence.onWriteForTesting = {
        guard !resumed else { return }
        resumed = true
        continuation.resume()
      }
      action()
    }
    persistence.onWriteForTesting = nil
  }

  @Test func aBurstOfSavesCoalescesIntoOneWriteOfTheLatestSnapshot() async {
    await waitForWrite {
      for index in 0..<10 { persistence.save(Self.snapshot(index: index)) }
    }
    try? await Task.sleep(for: Self.settleTime)

    #expect(persistence.debugWriteCount == 1)
    #expect(persistence.load()?.currentIndex == 9)
  }

  @Test func savesSeparatedByMoreThanTheDebounceWriteSeparately() async {
    await waitForWrite { persistence.save(Self.snapshot(index: 1)) }
    await waitForWrite { persistence.save(Self.snapshot(index: 2)) }

    #expect(persistence.debugWriteCount == 2)
    #expect(persistence.load()?.currentIndex == 2)
  }

  @Test func nothingIsOnDiskUntilTheDebounceElapses() {
    let slow = SessionPersistence(debounceInterval: 60, fileURL: fileURL)

    slow.save(Self.snapshot(index: 3))

    #expect(slow.load() == nil)
    #expect(slow.debugWriteCount == 0)
    slow.clear()
  }

  @Test func clearCancelsAPendingWrite() async {
    persistence.save(Self.snapshot(index: 4))
    persistence.clear()
    try? await Task.sleep(for: Self.settleTime)

    #expect(persistence.debugWriteCount == 0)
    #expect(persistence.load() == nil)
  }

  @Test func clearRemovesASavedSnapshot() async {
    await waitForWrite { persistence.save(Self.snapshot(index: 5)) }

    persistence.clear()
    try? await Task.sleep(for: Self.settleTime)

    #expect(persistence.load() == nil)
  }

  @Test func withNothingSavedLoadReturnsNil() {
    #expect(persistence.load() == nil)
  }

  @Test func aSavedSnapshotRoundTripsEveryField() async throws {
    let existing = AlbumRef.existing(localIdentifier: "album-1")
    let pending = AlbumRef.pendingNew(tempID: "temp-1", name: "Trip")
    var saved = Self.snapshot(index: 1)
    saved.historyPhotoIndices = [0]
    saved.historyPrevious = ["undecided"]
    saved.historyNew = ["keep"]
    saved.historyAdvanced = [true]
    saved.albumAdditions = ["a": [existing, pending]]
    saved.albumRemovals = ["b": ["album-2"]]
    saved.pendingNewAlbumRefs = [pending]

    await waitForWrite { persistence.save(saved) }

    let loaded = try #require(persistence.load())
    #expect(loaded.photoIDs == saved.photoIDs)
    #expect(loaded.decisions == saved.decisions)
    #expect(loaded.assetIdentifiers == saved.assetIdentifiers)
    #expect(loaded.currentIndex == saved.currentIndex)
    #expect(loaded.historyPhotoIndices == saved.historyPhotoIndices)
    #expect(loaded.historyPrevious == saved.historyPrevious)
    #expect(loaded.historyNew == saved.historyNew)
    #expect(loaded.historyAdvanced == saved.historyAdvanced)
    #expect(loaded.albumAdditions == saved.albumAdditions)
    #expect(loaded.albumRemovals == saved.albumRemovals)
    #expect(loaded.pendingNewAlbumRefs == saved.pendingNewAlbumRefs)
  }
}
