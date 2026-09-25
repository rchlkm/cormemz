// CoreMems/Models/RecentAlbums.swift
import Foundation

/// Most recently used album IDs, newest first, persisted across launches.
struct RecentAlbums {
  static let limit = 15
  private static let defaultsKey = "cm_recentAlbumIDs"

  private(set) var ids: [String]
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    ids = Array((defaults.stringArray(forKey: Self.defaultsKey) ?? []).prefix(Self.limit))
  }

  /// Only called when an album is turned on; turning one off leaves the list alone.
  mutating func record(_ identifier: String) {
    ids.removeAll { $0 == identifier }
    ids.insert(identifier, at: 0)
    if ids.count > Self.limit {
      ids.removeLast(ids.count - Self.limit)
    }
  }

  /// `pendingIDs` are session-local temp UUIDs, so they aren't stored.
  func persist(excluding pendingIDs: Set<String>) {
    defaults.set(ids.filter { !pendingIDs.contains($0) }, forKey: Self.defaultsKey)
  }
}
