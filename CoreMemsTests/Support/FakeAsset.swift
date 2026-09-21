// CoreMemsTests/Support/FakeAsset.swift
import Photos

@testable import CoreMems

/// A `PHAsset` with a chosen identifier and Live Photo flag, for feeding sessions
/// without a photo library.
final class FakeAsset: PHAsset, @unchecked Sendable {
  private let identifier: String
  private let isLive: Bool

  init(identifier: String, isLive: Bool = false) {
    self.identifier = identifier
    self.isLive = isLive
    super.init()
  }

  override var localIdentifier: String { identifier }
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
