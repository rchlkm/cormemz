// CoreMems/Services/PinnedAlbumsStore.swift
import Foundation

protocol PinnedAlbumsStoring {
  /// In the user's order.
  func pinnedAlbumIdentifiers() -> [String]
  /// Appends any that aren't pinned yet.
  func pin(_ identifiers: [String])
  func unpin(_ identifier: String)
  func setOrder(_ identifiers: [String])
}

/// Tracks which real Photos albums (`PHAssetCollection.localIdentifier`)
/// are "pinned" — the album picker defaults to showing just these instead
/// of the user's entire Photos library, in the order the user arranged them.
/// An album lands here either by the user pinning it explicitly
/// (Settings > Pinned Albums) or automatically when CoreMems creates it.
/// File-backed, same convention as `LifetimeStatsService`: survives
/// relaunch, cleared only if the app itself is deleted.
final class PinnedAlbumsStore: PinnedAlbumsStoring {
  private let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
      return
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("core-mems-pinned-albums.json")
  }

  func pinnedAlbumIdentifiers() -> [String] {
    guard let data = try? Data(contentsOf: fileURL),
      let ids = try? JSONDecoder().decode([String].self, from: data)
    else { return [] }
    return ids
  }

  func pin(_ identifiers: [String]) {
    let existing = pinnedAlbumIdentifiers()
    let added = identifiers.filter { !existing.contains($0) }
    guard !added.isEmpty else { return }
    setOrder(existing + added)
  }

  func unpin(_ identifier: String) {
    let ids = pinnedAlbumIdentifiers()
    guard ids.contains(identifier) else { return }
    setOrder(ids.filter { $0 != identifier })
  }

  func setOrder(_ identifiers: [String]) {
    guard let data = try? JSONEncoder().encode(identifiers) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}

#if DEBUG
  final class MockPinnedAlbumsStore: PinnedAlbumsStoring {
    var identifiers: [String] = []

    func pinnedAlbumIdentifiers() -> [String] { identifiers }
    func pin(_ identifiers: [String]) {
      self.identifiers += identifiers.filter { !self.identifiers.contains($0) }
    }
    func unpin(_ identifier: String) { identifiers.removeAll { $0 == identifier } }
    func setOrder(_ identifiers: [String]) { self.identifiers = identifiers }
  }
#endif
