// CoreMems/Services/DecidedPhotosStore.swift
import Foundation

protocol DecidedPhotosStoring {
  func decidedIdentifiers() -> Set<String>
  func markDecided(_ identifiers: Set<String>)
  func clear()
}

/// Remembers which photos (`PHAsset.localIdentifier`) the user has already
/// kept, so later sessions skip them.
/// File-backed, same convention as `PinnedAlbumsStore`.
final class DecidedPhotosStore: DecidedPhotosStoring {
  private let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
      return
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("core-mems-decided-photos.json")
  }

  func decidedIdentifiers() -> Set<String> {
    guard let data = try? Data(contentsOf: fileURL),
      let identifiers = try? JSONDecoder().decode(Set<String>.self, from: data)
    else { return [] }
    return identifiers
  }

  func markDecided(_ identifiers: Set<String>) {
    let existing = decidedIdentifiers()
    guard !identifiers.isSubset(of: existing) else { return }
    save(existing.union(identifiers))
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func save(_ identifiers: Set<String>) {
    guard let data = try? JSONEncoder().encode(identifiers.sorted()) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
