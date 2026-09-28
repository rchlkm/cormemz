// CoreMems/Services/VideoAssetLoader.swift
import AVFoundation
import Photos

/// Fetches an `AVPlayerItem` for a video asset. Kept separate from
/// `PhotoImageLoader` since video playback goes through PhotoKit's
/// `requestPlayerItem` API and hands back a playable item, not a `UIImage`.
actor VideoAssetLoader {
  static let shared = VideoAssetLoader()

  private let manager = PHCachingImageManager()
  private let networkAccess: NetworkAccessProviding

  init(networkAccess: NetworkAccessProviding = NetworkMonitor.shared) {
    self.networkAccess = networkAccess
  }

  func playerItem(for identifier: String) async -> AVPlayerItem? {
    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }

    let options = PHVideoRequestOptions()
    // .highQualityFormat delivers a single result, so the continuation resumes exactly once.
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = networkAccess.allowsDownloads

    return await withCheckedContinuation { continuation in
      manager.requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
        continuation.resume(returning: playerItem)
      }
    }
  }
}
