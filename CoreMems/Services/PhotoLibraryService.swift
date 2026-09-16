// CoreMems/Services/PhotoLibraryService.swift
import Photos
import PhotosUI
import UIKit

enum PhotoLibraryError: LocalizedError {
  case missingStillResource
  case creationFailed

  var errorDescription: String? {
    switch self {
    case .missingStillResource:
      return "This Live Photo has no still-image component to extract."
    case .creationFailed:
      return "The still photo couldn't be created."
    }
  }
}

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
  /// Extracts a Live Photo's still-image resource, saves it as a new
  /// standalone asset carrying over the original's creation date,
  /// location, and favorite status, then deletes the original Live
  /// Photo. The original is only deleted once the new still asset is
  /// confirmed created, so a failure never leaves the user with neither.
  /// Returns the new asset's local identifier.
  func convertLivePhotoToStill(_ asset: PHAsset) async -> Result<String, Error>
  /// Presents Apple's native limited-library picker so a Limited
  /// Photos Access user can grant access to more photos in-app.
  func presentLimitedLibraryPicker(from viewController: UIViewController)

  /// User-created albums only — `.album`/`.albumRegular` excludes
  /// Favorites, Recently Deleted, Screenshots, and other smart albums.
  func fetchUserAlbums() -> [AlbumOption]
  /// For a session's asset identifiers, which existing albums each is
  /// already in, keyed by `PHAsset.localIdentifier`.
  func fetchAlbumMembership(assetIdentifiers: Set<String>, albums: [AlbumOption]) -> [String:
    Set<String>]
  /// Commits staged album membership changes in a single
  /// `PHPhotoLibrary.performChanges` transaction, independent of
  /// `deleteAssets`. `assets` maps a session-scoped photoID to its
  /// backing `PHAsset`.
  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Void, Error>
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

  func convertLivePhotoToStill(_ asset: PHAsset) async -> Result<String, Error> {
    guard
      let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo })
    else {
      return .failure(PhotoLibraryError.missingStillResource)
    }

    let stillData: Data
    do {
      stillData = try await Self.data(for: resource)
    } catch {
      return .failure(error)
    }

    var newIdentifier: String?
    do {
      try await PHPhotoLibrary.shared().performChanges {
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .photo, data: stillData, options: nil)
        creationRequest.creationDate = asset.creationDate
        creationRequest.location = asset.location
        creationRequest.isFavorite = asset.isFavorite
        newIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
      }
    } catch {
      return .failure(error)
    }

    guard let newIdentifier else {
      return .failure(PhotoLibraryError.creationFailed)
    }

    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.deleteAssets([asset] as NSArray)
      }
    } catch {
      // The still photo already exists in the library even though the
      // original Live Photo couldn't be removed — surfacing this lets
      // the caller tell the user cleanup didn't fully finish.
      return .failure(error)
    }

    return .success(newIdentifier)
  }

  /// Downloads a `PHAssetResource`'s raw bytes (pulling from iCloud if
  /// the original isn't on-device), used here to carry a Live Photo's
  /// still component over as-is so its embedded EXIF survives untouched.
  private static func data(for resource: PHAssetResource) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      var data = Data()
      let options = PHAssetResourceRequestOptions()
      options.isNetworkAccessAllowed = true
      PHAssetResourceManager.default().requestData(
        for: resource,
        options: options,
        dataReceivedHandler: { chunk in data.append(chunk) },
        completionHandler: { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: data)
          }
        })
    }
  }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {
    if #available(iOS 15, *) {
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    } else {
      // Limited Library picker isn't available prior to iOS 15
    }
  }

  func fetchUserAlbums() -> [AlbumOption] {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
    let result = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .albumRegular, options: options)
    var albums: [AlbumOption] = []
    result.enumerateObjects { collection, _, _ in
      guard let title = collection.localizedTitle else { return }
      let count = collection.estimatedAssetCount
      albums.append(
        AlbumOption(
          ref: .existing(localIdentifier: collection.localIdentifier), name: title,
          assetCount: count == NSNotFound ? nil : count))
    }
    return albums
  }

  func fetchAlbumMembership(assetIdentifiers: Set<String>, albums: [AlbumOption]) -> [String:
    Set<String>]
  {
    guard !assetIdentifiers.isEmpty else { return [:] }
    var membership: [String: Set<String>] = [:]
    for album in albums where album.ref.kind == .existing {
      let albumID = album.ref.identifier
      guard
        let collection = PHAssetCollection.fetchAssetCollections(
          withLocalIdentifiers: [albumID], options: nil
        ).firstObject
      else { continue }
      let assetsInAlbum = PHAsset.fetchAssets(in: collection, options: nil)
      assetsInAlbum.enumerateObjects { asset, _, _ in
        guard assetIdentifiers.contains(asset.localIdentifier) else { return }
        membership[asset.localIdentifier, default: []].insert(albumID)
      }
    }
    return membership
  }

  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Void, Error> {
    guard !additions.isEmpty || !removals.isEmpty else { return .success(()) }
    do {
      try await PHPhotoLibrary.shared().performChanges {
        var assetsByExistingAddID: [String: [PHAsset]] = [:]
        var assetsByTempID: [String: [PHAsset]] = [:]
        var nameByTempID: [String: String] = [:]
        for (photoID, refs) in additions {
          guard let asset = assets[photoID] else { continue }
          for ref in refs {
            switch ref.kind {
            case .existing:
              assetsByExistingAddID[ref.identifier, default: []].append(asset)
            case .pendingNew:
              assetsByTempID[ref.identifier, default: []].append(asset)
              nameByTempID[ref.identifier] = ref.name
            }
          }
        }

        var assetsByExistingRemoveID: [String: [PHAsset]] = [:]
        for (photoID, ids) in removals {
          guard let asset = assets[photoID] else { continue }
          for id in ids {
            assetsByExistingRemoveID[id, default: []].append(asset)
          }
        }

        let existingIDs = Set(assetsByExistingAddID.keys).union(assetsByExistingRemoveID.keys)
        let collections = PHAssetCollection.fetchAssetCollections(
          withLocalIdentifiers: Array(existingIDs), options: nil)
        var collectionsByID: [String: PHAssetCollection] = [:]
        collections.enumerateObjects { collection, _, _ in
          collectionsByID[collection.localIdentifier] = collection
        }

        for (tempID, albumAssets) in assetsByTempID {
          guard let name = nameByTempID[tempID] else { continue }
          let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
            withTitle: name)
          request.addAssets(albumAssets as NSArray)
        }
        for (id, albumAssets) in assetsByExistingAddID {
          guard let collection = collectionsByID[id],
            let request = PHAssetCollectionChangeRequest(for: collection)
          else { continue }
          request.addAssets(albumAssets as NSArray)
        }
        for (id, albumAssets) in assetsByExistingRemoveID {
          guard let collection = collectionsByID[id],
            let request = PHAssetCollectionChangeRequest(for: collection)
          else { continue }
          request.removeAssets(albumAssets as NSArray)
        }
      }
      return .success(())
    } catch {
      return .failure(error)
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

  func convertLivePhotoToStill(_ asset: PHAsset) async -> Result<String, Error> {
    .success(asset.localIdentifier)
  }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}

  func fetchUserAlbums() -> [AlbumOption] { [] }

  func fetchAlbumMembership(assetIdentifiers: Set<String>, albums: [AlbumOption]) -> [String:
    Set<String>]
  { [:] }

  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Void, Error> { .success(()) }
}
