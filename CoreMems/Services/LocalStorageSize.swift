// CoreMems/Services/LocalStorageSize.swift
import Foundation

/// Total size of the files CoreMems keeps in its Application Support directory:
/// session progress, kept-photo history, pinned albums, and lifetime stats.
enum LocalStorageSize {
  static func totalBytes() -> Int64 {
    let fileManager = FileManager.default
    guard
      let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      let enumerator = fileManager.enumerator(
        at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil)
    else { return 0 }

    var total: Int64 = 0
    for case let url as URL in enumerator {
      let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
      total += Int64(size ?? 0)
    }
    return total
  }
}
