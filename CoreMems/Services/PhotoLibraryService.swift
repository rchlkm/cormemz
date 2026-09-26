// CoreMems/Services/PhotoLibraryService.swift
import Photos
import PhotosUI
import UIKit

/// The library's image assets in creation-date order. The sorted fetch is made once and
/// reused until `invalidate()`, since it covers the whole library.
private actor ChronologicalImages {
  private var cached: PHFetchResult<PHAsset>?

  func neighbors(of assetIdentifier: String, before: Int, after: Int) -> [PHAsset] {
    guard
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        .firstObject
    else { return [] }
    let result = cached ?? Self.fetch()
    cached = result
    let index = result.index(of: asset)
    guard index != NSNotFound else { return [] }
    let lower = max(0, index - before)
    let upper = min(result.count - 1, index + after)
    guard lower <= upper else { return [] }
    return (lower...upper).map { result.object(at: $0) }
  }

  func invalidate() { cached = nil }

  private static func fetch() -> PHFetchResult<PHAsset> {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: options)
  }
}

/// Library changes aren't observed. Live album updates would register a
/// `PHPhotoLibraryChangeObserver` here and call
/// `SessionViewModel.refreshLibraryAlbumsIfLoaded`.
final class PhotoLibraryService: PhotoLibraryServicing {
  private let chronologicalImages = ChronologicalImages()

  func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }

  func currentAuthorizationStatus() -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> any AssetBatching {
    await chronologicalImages.invalidate()
    return await Task.detached(priority: .userInitiated) {
      AssetBatchSource(mode: mode, startDate: startDate, excluding: excluding)
    }.value
  }

  func totalEligibleAssetCount() -> Int {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    return PHAsset.fetchAssets(with: options).count
  }

  func randomAssetDate() async -> Date? {
    await Task.detached(priority: .userInitiated) { () -> Date? in
      let options = PHFetchOptions()
      options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
      let result = PHAsset.fetchAssets(with: options)
      guard result.count > 0 else { return nil }
      return result.object(at: Int.random(in: 0..<result.count)).creationDate
    }.value
  }

  func neighborAssets(of assetIdentifier: String, before: Int, after: Int) async -> [PHAsset] {
    await chronologicalImages.neighbors(of: assetIdentifier, before: before, after: after)
  }

  /// PhotoKit has no public size API; `PHAssetResource` exposes it through the
  /// `fileSize` key, so the lookup is guarded against the key going away.
  nonisolated static func fileSize(of asset: PHAsset) -> Int64? {
    let sizeKey = "fileSize"
    var total: Int64 = 0
    for resource in PHAssetResource.assetResources(for: asset) {
      guard resource.responds(to: NSSelectorFromString(sizeKey)) else { return nil }
      total += (resource.value(forKey: sizeKey) as? NSNumber)?.int64Value ?? 0
    }
    return total
  }

  func storageSize(of assets: [PHAsset]) async -> Int64? {
    await Task.detached(priority: .userInitiated) { () -> Int64? in
      var total: Int64 = 0
      for asset in assets {
        guard let size = Self.fileSize(of: asset) else { return nil }
        total += size
      }
      return total
    }.value
  }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> {
    do {
      try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetChangeRequest(for: asset)
        request.isFavorite = isFavorite
      }
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {
    if #available(iOS 15, *) {
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    } else {
      // Limited Library picker isn't available prior to iOS 15
    }
  }
}
