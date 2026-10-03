// CoreMems/Services/KeptPhotosStore.swift
import Foundation

protocol KeptPhotosStoring {
  func keptIdentifiers() -> Set<String>
  func markKept(_ identifiers: Set<String>)
  func clear()
}

/// Remembers which photos (`PHAsset.localIdentifier`) the user has already
/// kept, so later sessions skip them.
/// File-backed, same convention as `PinnedAlbumsStore`.
final class KeptPhotosStore: KeptPhotosStoring {
  private let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
      return
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("core-mems-kept-photos.json")
    Self.migrateLegacyFile(to: self.fileURL, in: dir)
  }

  /// Moves the pre-rename file into place the first time; removable once devices
  /// have relaunched at least once past this build.
  private static func migrateLegacyFile(to fileURL: URL, in dir: URL) {
    let legacyURL = dir.appendingPathComponent("core-mems-decided-photos.json")
    guard !FileManager.default.fileExists(atPath: fileURL.path),
      FileManager.default.fileExists(atPath: legacyURL.path)
    else { return }
    try? FileManager.default.moveItem(at: legacyURL, to: fileURL)
  }

  func keptIdentifiers() -> Set<String> {
    guard let data = try? Data(contentsOf: fileURL),
      let identifiers = try? JSONDecoder().decode(Set<String>.self, from: data)
    else { return [] }
    return identifiers
  }

  func markKept(_ identifiers: Set<String>) {
    let existing = keptIdentifiers()
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
