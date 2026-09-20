// CoreMems/Services/PinnedAlbumsStore.swift
import Foundation

protocol PinnedAlbumsStoring {
  func pinnedAlbumIdentifiers() -> Set<String>
  func pin(_ identifiers: Set<String>)
  func unpin(_ identifier: String)
}

/// Tracks which real Photos albums (`PHAssetCollection.localIdentifier`)
/// are "pinned" — the album picker defaults to showing just these instead
/// of the user's entire Photos library. An album lands here either by the
/// user pinning it explicitly (Settings > Pinned Albums) or automatically
/// when CoreMems creates it. File-backed, same convention as
/// `LifetimeStatsService`: survives relaunch, cleared only if the app
/// itself is deleted.
final class PinnedAlbumsStore: PinnedAlbumsStoring {
  private let fileURL: URL

  init() {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("core-mems-pinned-albums.json")
  }

  func pinnedAlbumIdentifiers() -> Set<String> {
    guard let data = try? Data(contentsOf: fileURL),
      let ids = try? JSONDecoder().decode(Set<String>.self, from: data)
    else { return [] }
    return ids
  }

  func pin(_ identifiers: Set<String>) {
    guard !identifiers.isEmpty else { return }
    let merged = pinnedAlbumIdentifiers().union(identifiers)
    save(merged)
  }

  func unpin(_ identifier: String) {
    var ids = pinnedAlbumIdentifiers()
    guard ids.remove(identifier) != nil else { return }
    save(ids)
  }

  private func save(_ identifiers: Set<String>) {
    guard let data = try? JSONEncoder().encode(identifiers) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}

#if DEBUG
  final class MockPinnedAlbumsStore: PinnedAlbumsStoring {
    var identifiers: Set<String> = []

    func pinnedAlbumIdentifiers() -> Set<String> { identifiers }
    func pin(_ identifiers: Set<String>) { self.identifiers.formUnion(identifiers) }
    func unpin(_ identifier: String) { identifiers.remove(identifier) }
  }
#endif
