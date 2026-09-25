// CoreMems/Services/SessionCommitService.swift
import Photos

/// A converted Live Photo's still copy.
struct ConvertedStill {
  let identifier: String
  /// `nil` if the copy can't be re-fetched.
  let asset: PHAsset?
  /// Space freed by dropping the video; zero when a size is unknown.
  let bytesSaved: Int64
}

struct SessionCommitResult {
  let outcome: SessionLibraryResult
  let bytesDeleted: Int64
  /// Converted photos' still copies, by session photo ID.
  let stills: [String: ConvertedStill]
}

/// Commits a session's library changes and measures the space they free.
final class SessionCommitService {
  private let library: LibraryEditing

  init(library: LibraryEditing) {
    self.library = library
  }

  /// Sizes are read before the commit, since it deletes the originals.
  func commit(_ changes: SessionLibraryChanges) async -> Result<SessionCommitResult, Error> {
    let bytesDeleted = await library.storageSize(of: changes.deletions) ?? 0
    var originalSizes: [String: Int64] = [:]
    for (photoID, asset) in changes.conversions {
      originalSizes[photoID] = await library.storageSize(of: [asset])
    }

    let outcome: SessionLibraryResult
    switch await library.commitSessionChanges(changes) {
    case .success(let result): outcome = result
    case .failure(let error): return .failure(error)
    }

    var stills: [String: ConvertedStill] = [:]
    for (photoID, identifier) in outcome.stillIdentifiers {
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
      let bytesSaved = await spaceFreed(originalSize: originalSizes[photoID], newAsset: asset)
      stills[photoID] = ConvertedStill(
        identifier: identifier, asset: asset, bytesSaved: bytesSaved)
    }
    return .success(
      SessionCommitResult(outcome: outcome, bytesDeleted: bytesDeleted, stills: stills))
  }

  private func spaceFreed(originalSize: Int64?, newAsset: PHAsset?) async -> Int64 {
    guard let originalSize, let newAsset, let newSize = await library.storageSize(of: [newAsset])
    else { return 0 }
    return max(originalSize - newSize, 0)
  }
}
