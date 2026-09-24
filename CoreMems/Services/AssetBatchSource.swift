// CoreMems/Services/AssetBatchSource.swift
import Photos

/// A stream of assets handed out a batch at a time.
protocol AssetBatching: Actor {
  /// Returns up to `count` more assets; fewer than `count` means the source is exhausted.
  func nextBatch(count: Int) -> [PHAsset]
}

/// Walks the library's eligible (image-only) assets in a session's order, handing them out a
/// batch at a time so a session only materializes the photos it is about to show.
actor AssetBatchSource: AssetBatching {
  private let result: PHFetchResult<PHAsset>
  private let order: [Int]
  private let excluding: Set<String>
  private var cursor = 0

  /// Skips the local identifiers in `excluding`.
  init(mode: SelectionMode, startDate: Date?, excluding: Set<String>) {
    let options = PHFetchOptions()
    let image = PHAssetMediaType.image.rawValue
    switch mode {
    case .shuffle:
      options.predicate = NSPredicate(format: "mediaType == %d", image)
    case .recent:
      options.predicate = NSPredicate(format: "mediaType == %d", image)
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    case .date:
      options.predicate = NSPredicate(
        format: "mediaType == %d AND creationDate < %@",
        image, Self.dateCeiling(for: startDate) as NSDate)
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    }

    let result = PHAsset.fetchAssets(with: options)
    var positions = Array(0..<result.count)
    if case .shuffle = mode { positions.shuffle() }
    self.result = result
    self.order = positions
    self.excluding = excluding
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
