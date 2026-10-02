// CoreMems/Services/AssetReplacement.swift
import Photos

/// A new asset that takes an original's place in the library, carrying over its date,
/// location, favorite flag and albums. The original is deleted alongside it.
struct AssetReplacement {
  let original: PHAsset
  let resourceType: PHAssetResourceType
  let data: Data
  /// Albums the new asset joins in the original's place.
  let albumIDs: [String]

  /// Queues the new asset's creation; call inside `PHPhotoLibrary.performChanges`.
  func requestCreation() -> PHObjectPlaceholder? {
    let request = PHAssetCreationRequest.forAsset()
    request.addResource(with: resourceType, data: data, options: nil)
    request.creationDate = original.creationDate
    request.location = original.location
    request.isFavorite = original.isFavorite
    return request.placeholderForCreatedAsset
  }
}
