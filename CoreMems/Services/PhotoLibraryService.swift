// CoreMems/Services/PhotoLibraryService.swift
import Photos
import PhotosUI
import UIKit

/// PhotoKit wrapper
protocol PhotoLibraryServicing {
  func requestAuthorization() async -> PHAuthorizationStatus
  func currentAuthorizationStatus() -> PHAuthorizationStatus

  /// Fetches up to 'limit' eligible (image-only) assets
  func fetchRandomEligibleAssets(limit: Int) async -> [PHAsset]
  /// Fetches up to 'limit' eligible assets, most recently created first
  func fetchMostRecentEligibleAssets(limit: Int) async -> [PHAsset]
  /// Fetches eligible assets created at or after 'since', oldest first
  func fetchEligibleAssets(since: Date) async -> [PHAsset]
  func totalEligibleAssetCount() -> Int

  /// Submits confirmed assets for deletion via
  /// 'PHAssetChangeRequest.deleteAssets', which moves them to
  /// Recently Deleted per Apple's standard retention window.
  /// Returns the identifiers that failed, if any (empty = full success).
  func deleteAssets(_ assets: [PHAsset]) async -> Result<Void, Error>
  /// Writes the favorite flag to the Photos library via
  /// `PHAssetChangeRequest`. Callers should treat `.failure` as a
  /// signal to roll back any optimistic UI update.
  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error>
  /// Presents Apple's native limited-library picker so a Limited
  /// Photos Access user can grant access to more photos in-app.
  func presentLimitedLibraryPicker(from viewController: UIViewController)
}

final class PhotoLibraryService: PhotoLibraryServicing {

  func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }

  func currentAuthorizationStatus() -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  func fetchRandomEligibleAssets(limit: Int) async -> [PHAsset] {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

    let result = PHAsset.fetchAssets(with: options)
    var all: [PHAsset] = []
    all.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in all.append(asset) }

    // Insufficient-library case: requires the session to
    // silently shrink to the available count rather than error.
    guard !all.isEmpty else { return [] }
    let count = min(limit, all.count)
    return Array(all.shuffled().prefix(count))
  }

  func fetchMostRecentEligibleAssets(limit: Int) async -> [PHAsset] {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.fetchLimit = limit

    let result = PHAsset.fetchAssets(with: options)
    var assets: [PHAsset] = []
    assets.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in assets.append(asset) }
    return assets
  }

  func fetchEligibleAssets(since: Date) async -> [PHAsset] {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(
      format: "mediaType == %d AND creationDate >= %@",
      PHAssetMediaType.image.rawValue, since as NSDate)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

    let result = PHAsset.fetchAssets(with: options)
    var assets: [PHAsset] = []
    assets.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in assets.append(asset) }
    return assets
  }

  func totalEligibleAssetCount() -> Int {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    return PHAsset.fetchAssets(with: options).count
  }

  func deleteAssets(_ assets: [PHAsset]) async -> Result<Void, Error> {
    guard !assets.isEmpty else { return .success(()) }
    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.deleteAssets(assets as NSArray)
      }
      return .success(())
    } catch {
      return .failure(error)
    }
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

/// In-memory fake used by SwiftUI previews and the Dev Panel preview
/// states, so the UI can be built/reviewed without a device photo
/// library or Photos permission prompts.
final class MockPhotoLibraryService: PhotoLibraryServicing {
  var mockEligibleCount: Int = 200
  var mockAuthStatus: PHAuthorizationStatus = .authorized

  func requestAuthorization() async -> PHAuthorizationStatus { mockAuthStatus }
  func currentAuthorizationStatus() -> PHAuthorizationStatus { mockAuthStatus }

  func fetchRandomEligibleAssets(limit: Int) async -> [PHAsset] {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    []
  }

  func fetchMostRecentEligibleAssets(limit: Int) async -> [PHAsset] {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    []
  }

  func fetchEligibleAssets(since: Date) async -> [PHAsset] {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    []
  }

  func totalEligibleAssetCount() -> Int { mockEligibleCount }

  func deleteAssets(_ assets: [PHAsset]) async -> Result<Void, Error> { .success(()) }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> { .success(()) }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}
}
