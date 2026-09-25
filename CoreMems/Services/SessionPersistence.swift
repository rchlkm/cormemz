// CoreMems/Services/SessionPersistence.swift
import Foundation
import os

/// Only asset references + decision state, never image data
struct PersistedSessionSnapshot: Codable {
  var photoIDs: [String]
  var decisions: [String]  // ReviewDecision.rawValue
  var assetIdentifiers: [String]
  var currentIndex: Int
  var historyPhotoIndices: [Int]
  var historyPrevious: [String]
  var historyNew: [String]
  var historyAdvanced: [Bool]
  var albumAdditions: [String: Set<AlbumRef>] = [:]  // photoID -> albums to add
  var albumRemovals: [String: Set<String>] = [:]  // photoID -> existing album localIdentifiers to remove
  var heldPhotoIDs: [String] = []  // photos left out of the reviewed history
  var pendingNewAlbumRefs: [AlbumRef] = []  // session-created albums, kept pickable across a restart
}

protocol SessionPersisting {
  func save(_ snapshot: PersistedSessionSnapshot)
  func load() -> PersistedSessionSnapshot?
  func clear()
}

/// File-backed persistence in the app's Application Support directory.
/// Swapped for `UserDefaults` or Core Data if preferred — the important
/// part is that writes happen off the main thread and are debounced, so
/// a burst of rapid decisions (fast swiping) coalesces into a single
/// disk write instead of one per decision.
final class SessionPersistence: SessionPersisting {
  private static let logger = Logger(subsystem: "com.coremems", category: "performance")

  private let fileURL: URL
  private let queue = DispatchQueue(label: "com.coremems.session-persistence", qos: .utility)
  private var pendingWrite: DispatchWorkItem?
  private let debounceInterval: TimeInterval

  /// Fires on the background queue immediately after a debounced write
  /// actually lands on disk. Lets tests observe coalescing and timing
  /// without touching the filesystem directly. No-op in release builds.
  #if DEBUG
    var onWriteForTesting: (() -> Void)?
    private(set) var debugWriteCount = 0
  #endif

  init(debounceInterval: TimeInterval = 0.3, fileURL: URL? = nil) {
    self.debounceInterval = debounceInterval
    if let fileURL {
      self.fileURL = fileURL
      return
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    // The Application Support directory is not created automatically on iOS.
    // Without this, writes fail silently and the snapshot never persists.
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("core-mems-active-session.json")
  }

  /// Debounces rapid successive calls (e.g. quick swipes) into a single
  /// background write of the latest snapshot, keeping the caller's
  /// thread free of disk I/O.
  func save(_ snapshot: PersistedSessionSnapshot) {
    pendingWrite?.cancel()
    let fileURL = fileURL
    let workItem = DispatchWorkItem { [weak self] in
      guard let data = try? JSONEncoder().encode(snapshot) else { return }
      try? data.write(to: fileURL, options: .atomic)
      Self.logger.debug("wrote session snapshot (\(data.count) bytes)")
      #if DEBUG
        self?.debugWriteCount += 1
        self?.onWriteForTesting?()
      #endif
    }
    pendingWrite = workItem
    queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
  }

  func load() -> PersistedSessionSnapshot? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? JSONDecoder().decode(PersistedSessionSnapshot.self, from: data)
  }

  func clear() {
    pendingWrite?.cancel()
    queue.async { [fileURL] in
      try? FileManager.default.removeItem(at: fileURL)
    }
  }
}

#if DEBUG
  final class MockSessionPersistence: SessionPersisting {
    private(set) var snapshot: PersistedSessionSnapshot?

    func save(_ snapshot: PersistedSessionSnapshot) { self.snapshot = snapshot }
    func load() -> PersistedSessionSnapshot? { snapshot }
    func clear() { snapshot = nil }
  }
#endif
