// CoreMems/Services/AssetBatchSource.swift
import Photos

/// A stream of assets handed out a batch at a time.
protocol AssetBatching: Actor {
  /// Returns up to `count` more assets; fewer than `count` means the source is exhausted.
  func nextBatch(count: Int) async -> [PHAsset]
}

/// Walks the library's eligible (image-only) assets in a session's order, handing them out a
/// batch at a time so a session only materializes the photos it is about to show.
actor AssetBatchSource: AssetBatching {
  private let result: PHFetchResult<PHAsset>
  private let order: [Int]
  private let excluding: Set<String>
  private var cursor = 0

  /// Skips the local identifiers in `excluding`. `albumIdentifier` applies to `.album`.
  init(
    mode: SelectionMode, startDate: Date?, albumIdentifier: String?,
    mediaTypeFilter: MediaTypeFilter = .all, excluding: Set<String>
  ) {
    let options = PHFetchOptions()
    let basePredicate = Self.mediaTypePredicate(mediaTypeFilter)
    let result: PHFetchResult<PHAsset>
    switch mode {
    case .shuffle:
      options.predicate = basePredicate
      result = PHAsset.fetchAssets(with: options)
    case .recent:
      options.predicate = basePredicate
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      result = PHAsset.fetchAssets(with: options)
    case .date:
      options.predicate = NSCompoundPredicate(
        andPredicateWithSubpredicates: [
          basePredicate,
          NSPredicate(
            format: "creationDate < %@", Self.dateCeiling(for: startDate) as NSDate),
        ])
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      result = PHAsset.fetchAssets(with: options)
    case .album:
      options.predicate = basePredicate
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      if let albumIdentifier,
        let collection = PHAssetCollection.fetchAssetCollections(
          withLocalIdentifiers: [albumIdentifier], options: nil
        ).firstObject
      {
        result = PHAsset.fetchAssets(in: collection, options: options)
      } else {
        result = PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
      }
    }

    var positions = Array(0..<result.count)
    if case .shuffle = mode { positions.shuffle() }
    self.result = result
    self.order = positions
    self.excluding = excluding
  }

  static func mediaTypePredicate(_ filter: MediaTypeFilter) -> NSPredicate {
    switch filter {
    case .screenshots:
      return NSPredicate(
        format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
        PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
    case .photos:
      return NSPredicate(
        format: "mediaType == %d AND (mediaSubtypes & %d) == 0",
        PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
    case .videos:
      return NSPredicate(
        format: "mediaType == %d AND (mediaSubtypes & %d) == 0",
        PHAssetMediaType.video.rawValue, PHAssetMediaSubtype.videoTimelapse.rawValue)
    case .timelapses:
      return NSPredicate(
        format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
        PHAssetMediaType.video.rawValue, PHAssetMediaSubtype.videoTimelapse.rawValue)
    case .all:
      return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    }
  }

  /// Exclusive upper bound that includes all of the chosen day, whatever time of day the
  /// date carries.
  static func dateCeiling(for startDate: Date?) -> Date {
    guard let startDate else { return .distantFuture }
    let calendar = Calendar.current
    return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate))
      ?? .distantFuture
  }

  /// A source with no assets.
  init() {
    result = PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
    order = []
    excluding = []
  }

  func nextBatch(count: Int) -> [PHAsset] {
    var batch: [PHAsset] = []
    while batch.count < count, cursor < order.count {
      let asset = result.object(at: order[cursor])
      cursor += 1
      guard !excluding.contains(asset.localIdentifier) else { continue }
      batch.append(asset)
    }
    return batch
  }
}

/// Hands out only the assets of `base` that pass `admits`, refilling each batch from
/// `base` until it is full or `base` runs dry.
actor FilteringAssetSource: AssetBatching {
  private let base: any AssetBatching
  private let admits: @Sendable (PHAsset) async -> Bool
  private var isExhausted = false

  init(base: any AssetBatching, admits: @escaping @Sendable (PHAsset) async -> Bool) {
    self.base = base
    self.admits = admits
  }

  func nextBatch(count: Int) async -> [PHAsset] {
    var batch: [PHAsset] = []
    let admits = admits
    while batch.count < count, !isExhausted {
      let wanted = count - batch.count
      let candidates = await base.nextBatch(count: wanted)
      if candidates.count < wanted { isExhausted = true }
      // Each candidate's admission is an independent PHImageManager probe, so
      // running them concurrently avoids paying that latency once per photo
      // in a row when a batch has many cloud-only assets to reject. Indexed
      // so the admitted assets stay in `candidates`' order, not completion order.
      let admitted = await withTaskGroup(of: (Int, PHAsset?).self) { group in
        for (index, asset) in candidates.enumerated() {
          group.addTask { (index, await admits(asset) ? asset : nil) }
        }
        var results = [PHAsset?](repeating: nil, count: candidates.count)
        for await (index, asset) in group {
          results[index] = asset
        }
        return results.compactMap { $0 }
      }
      batch.append(contentsOf: admitted)
    }
    return batch
  }
}
