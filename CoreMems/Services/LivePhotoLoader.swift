// CoreMems/Services/LivePhotoLoader.swift
import AVFoundation
import Photos

/// Fetches `PHLivePhoto` playback data and video frames for a given asset. Kept
/// separate from `PhotoImageLoader` since Live Photo requests go
/// through PhotoKit's own `requestLivePhoto` API and hand back a
/// playable type, not a `UIImage`.
actor LivePhotoLoader {
  static let shared = LivePhotoLoader()

  private let manager = PHCachingImageManager()
  private let networkAccess: NetworkAccessProviding

  init(networkAccess: NetworkAccessProviding = NetworkMonitor.shared) {
    self.networkAccess = networkAccess
  }

  func livePhoto(for identifier: String, targetSize: CGSize) async -> PHLivePhoto? {
    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }

    let options = PHLivePhotoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = networkAccess.allowsDownloads

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

  /// The frames of the asset's Live Photo video; `nil` if they can't be read.
  func frames(for identifier: String) async -> LivePhotoFrames? {
    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject,
      let resource = Self.pairedVideo(of: asset)
    else {
      return nil
    }
    let allowsNetwork = networkAccess.allowsDownloads
    guard
      let input = try? await MediaEditRenderer.contentEditingInput(
        for: asset, allowsNetwork: allowsNetwork),
      let context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
    else {
      return nil
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension(for: .quickTimeMovie)
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = allowsNetwork
    do {
      try await PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options)
    } catch {
      return nil
    }
    return LivePhotoFrames(
      videoURL: url, duration: context.duration.seconds, keyPhotoTime: context.photoTime.seconds)
  }

  /// The edited video if the Live Photo has one, matching the version the renderer edits.
  private static func pairedVideo(of asset: PHAsset) -> PHAssetResource? {
    let resources = PHAssetResource.assetResources(for: asset)
    return resources.first { $0.type == .fullSizePairedVideo }
      ?? resources.first { $0.type == .pairedVideo }
  }
}
