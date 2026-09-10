import Foundation

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
}

protocol SessionPersisting {
  func save(_ snapshot: PersistedSessionSnapshot)
  func load() -> PersistedSessionSnapshot?
  func clear()
}

/// File-backed persistence in the app's Application Support directory.
/// Swapped for `UserDefaults` or Core Data if preferred — the important
final class SessionPersistence: SessionPersisting {
  private let fileURL: URL

  init() {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    fileURL = dir.appendingPathComponent("core-mems-active-session.json")
  }

  func save(_ snapshot: PersistedSessionSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }

  func load() -> PersistedSessionSnapshot? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? JSONDecoder().decode(PersistedSessionSnapshot.self, from: data)
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
