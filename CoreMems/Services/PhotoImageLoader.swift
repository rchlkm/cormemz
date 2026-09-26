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

  /// Produces the image for an identifier at a size; must stop early when its task is cancelled.
  typealias ImageFetch = @Sendable (_ identifier: String, _ targetSize: CGSize) async -> UIImage?

  private struct InFlightLoad {
    let id: UUID
    let task: Task<UIImage?, Never>
    var waiters: Int
  }

  private static let logger = Logger(subsystem: "com.coremems", category: "performance")
  private static let signposter = OSSignposter(subsystem: "com.coremems", category: "performance")

  private let manager: PHCachingImageManager
  private let fetch: ImageFetch
  /// Assets the app already holds, so a request doesn't re-fetch them by identifier.
  private let knownAssets = NSCache<NSString, PHAsset>()
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
  private var inFlight: [String: InFlightLoad] = [:]

  init(fetch: ImageFetch? = nil) {
    let manager = PHCachingImageManager()
    let knownAssets = knownAssets
    self.manager = manager
    self.fetch = fetch ?? { identifier, targetSize in
      await Self.requestImage(
        using: manager, knownAssets: knownAssets, identifier: identifier, targetSize: targetSize)
    }
    cache.delegate = evictionLogger
  }

  deinit {
    cache.delegate = nil
  }

  nonisolated func register(_ assets: [PHAsset]) {
    for asset in assets { knownAssets.setObject(asset, forKey: asset.localIdentifier as NSString) }
  }

  /// Callers asking for the same image at the same time share one load. The load is cancelled
  /// only once every caller waiting on it has been cancelled.
  func image(for identifier: String, targetSize: CGSize) async -> UIImage? {
    let cacheKey = "\(identifier)-\(Int(targetSize.width))x\(Int(targetSize.height))"
    if let cached = cache.object(forKey: cacheKey as NSString) {
      Self.logger.debug("cache hit for \(cacheKey, privacy: .public)")
      return cached
    }

    let load = joinLoad(key: cacheKey, identifier: identifier, targetSize: targetSize)
    return await withTaskCancellationHandler {
      await load.task.value
    } onCancel: {
      Task { await self.leaveLoad(key: cacheKey, id: load.id) }
    }
  }

  private func joinLoad(key: String, identifier: String, targetSize: CGSize) -> InFlightLoad {
    if var load = inFlight[key] {
      load.waiters += 1
      inFlight[key] = load
      return load
    }
    let id = UUID()
    let load = InFlightLoad(
      id: id,
      task: Task {
        await self.runLoad(key: key, id: id, identifier: identifier, targetSize: targetSize)
      },
      waiters: 1)
    inFlight[key] = load
    return load
  }

  private func leaveLoad(key: String, id: UUID) {
    guard var load = inFlight[key], load.id == id else { return }
    load.waiters -= 1
    if load.waiters > 0 {
      inFlight[key] = load
      return
    }
    load.task.cancel()
    inFlight[key] = nil
  }

  private func runLoad(
    key: String, id: UUID, identifier: String, targetSize: CGSize
  ) async -> UIImage? {
    let signpostID = Self.signposter.makeSignpostID()
    let state = Self.signposter.beginInterval("LoadImage", id: signpostID)
    defer { Self.signposter.endInterval("LoadImage", state) }

    let image = await fetch(identifier, targetSize)
    if let image, !Task.isCancelled { store(image, key: key as NSString) }
    if inFlight[key]?.id == id { inFlight[key] = nil }
    return image
  }

  private static func requestImage(
    using manager: PHCachingImageManager, knownAssets: NSCache<NSString, PHAsset>,
    identifier: String, targetSize: CGSize
  ) async -> UIImage? {
    guard
      let asset = knownAssets.object(forKey: identifier as NSString)
        ?? PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false
    #if DEBUG
      let transfer = NetworkTransferProbe()
      options.progressHandler = { _, _, _, _ in transfer.markTransferred() }
    #endif

    // .highQualityFormat delivers a single result, and Photos also calls back once
    // when the request is cancelled, so the continuation resumes exactly once.
    let token = RequestToken()
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        let id = manager.requestImage(
          for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
        ) { image, _ in
          #if DEBUG
            if image != nil, transfer.didTransfer { NetworkDownloadStats.recordDownload(of: asset) }
          #endif
          continuation.resume(returning: image)
        }
        token.attach(id, to: manager)
      }
    } onCancel: {
      token.cancel()
    }
  }

  /// Loads exactly one upcoming photo ahead of when the user reaches
  /// it. Cancels the previous prefetch first, which stops its download
  /// unless the visible card is waiting on the same image.
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
    knownAssets.removeAllObjects()
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

/// Cancels a Photos request that may be cancelled before or after it has an ID.
nonisolated private final class RequestToken: @unchecked Sendable {
  private let lock = NSLock()
  private var requestID: PHImageRequestID?
  private var manager: PHImageManager?
  private var isCancelled = false

  func attach(_ id: PHImageRequestID, to manager: PHImageManager) {
    lock.lock()
    defer { lock.unlock() }
    if isCancelled {
      manager.cancelImageRequest(id)
    } else {
      requestID = id
      self.manager = manager
    }
  }

  func cancel() {
    lock.lock()
    defer { lock.unlock() }
    isCancelled = true
    if let requestID { manager?.cancelImageRequest(requestID) }
  }
}
