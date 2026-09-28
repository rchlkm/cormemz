// CoreMemsTests/Support/FakeAsset.swift
import Photos

@testable import CoreMems

/// A `PHAsset` with a chosen identifier, Live Photo flag, and media type, for
/// feeding sessions without a photo library.
final class FakeAsset: PHAsset, @unchecked Sendable {
  private let identifier: String
  private let isLive: Bool
  private let isVideo: Bool

  init(identifier: String, isLive: Bool = false, isVideo: Bool = false) {
    self.identifier = identifier
    self.isLive = isLive
    self.isVideo = isVideo
    super.init()
  }

  override var localIdentifier: String { identifier }
  override var mediaType: PHAssetMediaType { isVideo ? .video : .image }
  override var mediaSubtypes: PHAssetMediaSubtype { isLive ? .photoLive : [] }
  override var isFavorite: Bool { false }
  override var creationDate: Date? { nil }
}

/// Hands out a fixed list of assets, like a small library.
actor FakeAssetSource: AssetBatching {
  private var remaining: [PHAsset]
  private(set) var requestedBatchSizes: [Int] = []

  init(assets: [PHAsset]) {
    remaining = assets
  }

  func nextBatch(count: Int) -> [PHAsset] {
    requestedBatchSizes.append(count)
    let batch = Array(remaining.prefix(count))
    remaining.removeFirst(batch.count)
    return batch
  }
}
