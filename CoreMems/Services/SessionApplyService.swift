// CoreMems/Services/SessionApplyService.swift
import Photos

/// A converted Live Photo's still copy.
struct ConvertedStill {
  let identifier: String
  /// `nil` if the copy can't be re-fetched.
  let asset: PHAsset?
  /// Space freed by dropping the video; zero when a size is unknown.
  let bytesSaved: Int64
}

struct SessionApplyResult {
  let outcome: SessionLibraryResult
  let bytesDeleted: Int64
  /// Space freed by trimmed videos whose originals were deleted, net of their clips.
  let bytesSavedByTrimming: Int64
  /// Converted photos' still copies, by session photo ID.
  let stills: [String: ConvertedStill]
}

/// Applies a session's library changes and measures the space they free.
final class SessionApplyService {
  private let library: LibraryEditing

  init(library: LibraryEditing) {
    self.library = library
  }

  /// Sizes are read before the apply, since it deletes the originals.
  func apply(_ changes: SessionLibraryChanges) async -> Result<SessionApplyResult, Error> {
    let bytesDeleted = await library.storageSize(of: changes.deletions) ?? 0
    var originalSizes: [String: Int64] = [:]
    for (photoID, asset) in changes.conversions {
      originalSizes[photoID] = await library.storageSize(of: [asset])
    }
    var trimmedOriginalSizes: [String: Int64] = [:]
    for (photoID, staged) in changes.edits
    where staged.edit.trimRange != nil && staged.edit.deletesOriginal {
      trimmedOriginalSizes[photoID] = await library.storageSize(of: [staged.asset])
    }

    let outcome: SessionLibraryResult
    switch await library.applySessionChanges(changes) {
    case .success(let result): outcome = result
    case .failure(let error): return .failure(error)
    }

    var stills: [String: ConvertedStill] = [:]
    for (photoID, identifier) in outcome.stillIdentifiers {
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
      stills[photoID] = ConvertedStill(
        identifier: identifier, asset: asset,
        bytesSaved: spaceFreed(
          originalSize: originalSizes[photoID], replacementSize: outcome.stillSizes[photoID]))
    }
    let bytesSavedByTrimming = outcome.clipSizes.reduce(0) { total, clip in
      total
        + spaceFreed(originalSize: trimmedOriginalSizes[clip.key], replacementSize: clip.value)
    }
    return .success(
      SessionApplyResult(
        outcome: outcome, bytesDeleted: bytesDeleted, bytesSavedByTrimming: bytesSavedByTrimming,
        stills: stills))
  }

  private func spaceFreed(originalSize: Int64?, replacementSize: Int64?) -> Int64 {
    guard let originalSize, let replacementSize else { return 0 }
    return max(originalSize - replacementSize, 0)
  }
}
