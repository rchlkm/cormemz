// CoreMems/Services/AssetReplacement.swift
import Photos

/// A new asset made from an original, carrying over its date, location, favorite flag and
/// albums. The original is deleted alongside it unless `deletesOriginal` is off.
struct AssetReplacement {
  enum Content {
    case data(Data)
    case file(URL)
  }

  let original: PHAsset
  let resourceType: PHAssetResourceType
  let content: Content
  /// Albums the new asset joins in the original's place.
  let albumIDs: [String]
  var deletesOriginal = true

  /// The new asset's size in bytes when it's held in memory.
  var dataSize: Int64? {
    guard case .data(let data) = content else { return nil }
    return Int64(data.count)
  }

  /// Queues the new asset's creation; call inside `PHPhotoLibrary.performChanges`.
  func requestCreation() -> PHObjectPlaceholder? {
    let request = PHAssetCreationRequest.forAsset()
    switch content {
    case .data(let data): request.addResource(with: resourceType, data: data, options: nil)
    case .file(let url): request.addResource(with: resourceType, fileURL: url, options: nil)
    }
    request.creationDate = original.creationDate
    request.location = original.location
    request.isFavorite = original.isFavorite
    return request.placeholderForCreatedAsset
  }
}
