import Photos
import UIKit

/// Loads appropriately-sized thumbnails for real `PHAsset`s.
///
/// Satisfies the §8 Non-Functional Requirement: "Photo review must use
/// appropriately-sized image representations rather than loading
/// full-resolution originals for every swipe" and "memory usage during
/// rapid sequential review must not grow unbounded — prior off-screen
/// images should be released."
///
/// The bounded `cache` dictionary caps retained images; SwiftUI itself
/// releases `AdaptiveAssetImage` instances (and their `@State` image)
/// once a card scrolls off-screen, which handles the rest of the
/// "release off-screen images" requirement for free.
actor PhotoImageLoader {
  static let shared = PhotoImageLoader()

  private let manager = PHCachingImageManager()
  private var cache: [String: UIImage] = [:]
  private var cacheOrder: [String] = []
  private let maxCachedImages = 60

  func image(for identifier: String, targetSize: CGSize) async -> UIImage? {
    let cacheKey = "\(identifier)-\(Int(targetSize.width))x\(Int(targetSize.height))"
    if let cached = cache[cacheKey] { return cached }

    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    // PHImageManager's completion can theoretically fire more than
    // once (once for a fast degraded image, once for the final
    // high-quality one) when deliveryMode is .opportunistic — we use
    // .highQualityFormat specifically to avoid that here and keep
    // this a single-shot continuation.
    return await withCheckedContinuation { continuation in
      manager.requestImage(
        for: asset,
        targetSize: targetSize,
        contentMode: .aspectFill,
        options: options
      ) { [weak self] image, _ in
        guard let self else {
          continuation.resume(returning: image)
          return
        }
        if let image {
          Task { await self.store(image, key: cacheKey) }
        }
        continuation.resume(returning: image)
      }
    }
  }

  /// Pre-warms the cache for upcoming cards so swiping feels instant —
  /// mirrors `PHCachingImageManager.startCachingImages` intent without
  /// needing to hand out raw PHAssets to the view layer.
  func prefetch(identifiers: [String], targetSize: CGSize) {
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
    var toCache: [PHAsset] = []
    assets.enumerateObjects { asset, _, _ in toCache.append(asset) }
    guard !toCache.isEmpty else { return }
    manager.startCachingImages(
      for: toCache, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  private func store(_ image: UIImage, key: String) {
    if cache[key] == nil {
      cacheOrder.append(key)
    }
    cache[key] = image
    while cacheOrder.count > maxCachedImages {
      let oldest = cacheOrder.removeFirst()
      cache.removeValue(forKey: oldest)
    }
  }

  func clearCache() {
    cache.removeAll()
    cacheOrder.removeAll()
    manager.stopCachingImagesForAllAssets()
  }
}
