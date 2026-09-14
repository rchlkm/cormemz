// CoreMems/Services/LivePhotoLoader.swift
import Photos

/// Fetches `PHLivePhoto` playback data for a given asset. Kept
/// separate from `PhotoImageLoader` since Live Photo requests go
/// through PhotoKit's own `requestLivePhoto` API and hand back a
/// playable type, not a `UIImage`.
actor LivePhotoLoader {
  static let shared = LivePhotoLoader()

  private let manager = PHCachingImageManager()

  func livePhoto(for identifier: String, targetSize: CGSize) async -> PHLivePhoto? {
    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }

    let options = PHLivePhotoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true

    return await withCheckedContinuation { continuation in
      manager.requestLivePhoto(
        for: asset,
        targetSize: targetSize,
        contentMode: .aspectFit,
        options: options
      ) { livePhoto, _ in
        continuation.resume(returning: livePhoto)
      }
    }
  }
}
