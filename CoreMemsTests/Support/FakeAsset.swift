// CoreMemsTests/Support/FakeAsset.swift
import Photos

@testable import CoreMems

/// A `PHAsset` with a chosen identifier, media type and subtypes, and length, for
/// feeding sessions without a photo library.
final class FakeAsset: PHAsset, @unchecked Sendable {
  private let identifier: String
  private let isLive: Bool
  private let isVideo: Bool
  private let kind: MediaKind?
  private let length: TimeInterval

  init(
    identifier: String, isLive: Bool = false, isVideo: Bool = false, kind: MediaKind? = nil,
    duration: TimeInterval = 0
  ) {
    self.identifier = identifier
    self.isLive = isLive
    self.isVideo = isVideo
    self.kind = kind
    self.length = duration
    super.init()
  }

  override var localIdentifier: String { identifier }
  override var mediaType: PHAssetMediaType { isVideo ? .video : .image }
  override var mediaSubtypes: PHAssetMediaSubtype {
    var subtypes: PHAssetMediaSubtype = []
    if isLive { subtypes.insert(.photoLive) }
    if let kind { subtypes.insert(kind.subtype) }
    return subtypes
  }
  override var duration: TimeInterval { length }
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
