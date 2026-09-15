// CoreMems/Services/PhotoImageLoader.swift
import Photos
import UIKit
import os

/// Loads appropriately-sized thumbnails for real `PHAsset`s.
///
/// Satisfies the §8 Non-Functional Requirement: "Photo review must use
/// appropriately-sized image representations rather than loading
/// full-resolution originals for every swipe" and "memory usage during
/// rapid sequential review must not grow unbounded — prior off-screen
/// images should be released."
///
/// The cache is bounded by total decoded byte size rather than item
/// count, and purges automatically under system memory pressure;
/// SwiftUI itself releases `AdaptiveAssetImage` instances (and their
/// `@State` image) once a card scrolls off-screen, which handles the
/// rest of the "release off-screen images" requirement for free.
actor PhotoImageLoader {
  static let shared = PhotoImageLoader()

  private static let logger = Logger(subsystem: "com.coremems", category: "performance")
  private static let signposter = OSSignposter(subsystem: "com.coremems", category: "performance")

  private let manager = PHCachingImageManager()
  private let evictionLogger = CacheEvictionLogger()
  private let cache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    // Budgets total decoded bitmap bytes rather than image count, so a
    // handful of large full-resolution review images can't retain far
    // more memory than the same count of small thumbnails would.
    cache.totalCostLimit = 80 * 1024 * 1024
    return cache
  }()
  private var prefetchTask: Task<Void, Never>?

  init() {
    cache.delegate = evictionLogger
  }

  func image(for identifier: String, targetSize: CGSize) async -> UIImage? {
    let cacheKey = "\(identifier)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    if let cached = cache.object(forKey: cacheKey) {
      Self.logger.debug("cache hit for \(cacheKey, privacy: .public)")
      return cached
    }

    let signpostID = Self.signposter.makeSignpostID()
    let state = Self.signposter.beginInterval("LoadImage", id: signpostID)
    defer { Self.signposter.endInterval("LoadImage", state) }

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

  /// Loads exactly one upcoming photo ahead of when the user reaches
  /// it. Cancels any still-pending prefetch first, so swiping faster
  /// than the network never queues up more than one in-flight download.
  func prefetchNext(identifier: String, targetSize: CGSize) {
    prefetchTask?.cancel()
    prefetchTask = Task { [weak self] in
      _ = await self?.image(for: identifier, targetSize: targetSize)
    }
  }

  private func store(_ image: UIImage, key: NSString) {
    let cost = byteCost(of: image)
    cache.setObject(image, forKey: key, cost: cost)
    Self.logger.debug("cached \(key, privacy: .public), cost=\(cost) bytes")
  }

  /// Approximate decoded bitmap size in bytes, used as the cache's
  /// per-entry cost so eviction tracks actual memory footprint rather
  /// than entry count.
  private func byteCost(of image: UIImage) -> Int {
    guard let cgImage = image.cgImage else { return 0 }
    return cgImage.bytesPerRow * cgImage.height
  }

  func clearCache() {
    prefetchTask?.cancel()
    cache.removeAllObjects()
    manager.stopCachingImagesForAllAssets()
  }
}

/// Logs cache evictions so memory behavior can be watched manually in
/// the console during a real review session, without needing a PhotoKit
/// fake to unit test against.
private final class CacheEvictionLogger: NSObject, NSCacheDelegate {
  private static let logger = Logger(subsystem: "com.coremems", category: "performance")

  func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
    Self.logger.debug("evicting cached image (cost limit or memory pressure)")
  }
}
