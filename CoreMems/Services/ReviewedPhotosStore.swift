// CoreMems/Services/ReviewedPhotosStore.swift
import Foundation

protocol ReviewedPhotosStoring {
  func reviewedIdentifiers() -> Set<String>
  func markReviewed(_ identifiers: Set<String>)
  func clear()
}

/// Remembers which photos (`PHAsset.localIdentifier`) the user has already
/// kept, so later sessions skip them. Each entry keeps its review date.
/// File-backed, same convention as `PinnedAlbumsStore`.
final class ReviewedPhotosStore: ReviewedPhotosStoring {
  private let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
      return
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("core-mems-reviewed-photos.json")
  }

  func reviewedIdentifiers() -> Set<String> {
    Set(loadEntries().keys)
  }

  func markReviewed(_ identifiers: Set<String>) {
    var entries = loadEntries()
    let now = Date()
    let newIdentifiers = identifiers.filter { entries[$0] == nil }
    guard !newIdentifiers.isEmpty else { return }
    for identifier in newIdentifiers { entries[identifier] = now }
    save(entries)
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func loadEntries() -> [String: Date] {
    guard let data = try? Data(contentsOf: fileURL),
      let entries = try? JSONDecoder().decode([String: Date].self, from: data)
    else { return [:] }
    return entries
  }

  private func save(_ entries: [String: Date]) {
    guard let data = try? JSONEncoder().encode(entries) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
