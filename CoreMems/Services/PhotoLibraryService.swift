// CoreMems/Services/PhotoLibraryService.swift
import Photos
import PhotosUI
import UIKit

enum PhotoLibraryError: LocalizedError {
  case missingStillResource
  case creationFailed
  case albumCreationFailed

  var errorDescription: String? {
    switch self {
    case .missingStillResource:
      return "This Live Photo has no still-image component to extract."
    case .creationFailed:
      return "The still photo couldn't be created."
    case .albumCreationFailed:
      return "The album couldn't be created."
    }
  }
}

/// PhotoKit wrapper
protocol PhotoLibraryServicing {
  func requestAuthorization() async -> PHAuthorizationStatus
  func currentAuthorizationStatus() -> PHAuthorizationStatus

  /// Opens the eligible (image-only) assets for `mode` as a lazily loaded stream,
  /// skipping the local identifiers in 'excluding'. `startDate` applies to `.date`.
  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> AssetBatchSource
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

  /// Every user-created album (names and counts only); `.albumRegular`
  /// excludes smart albums like Favorites. Runs off the main thread.
  func fetchAllUserAlbums() async -> [AlbumOption]
  /// Identifiers of every user album containing the asset. A direct lookup
  /// for one asset, so it stays fast at any library size. Runs off the main thread.
  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String>
  /// Commits staged album membership changes in a single
  /// `PHPhotoLibrary.performChanges` transaction, independent of
  /// `deleteAssets`. `assets` maps a session-scoped photoID to its
  /// backing `PHAsset`. On success, returns the real
  /// `PHAssetCollection.localIdentifier`s of any brand-new albums that
  /// were created (i.e. former `.pendingNew` refs), so the caller can
  /// remember them as app-created.
  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Set<String>, Error>
  /// Creates a real, empty Photos album with the given title — used by
  /// the Pinned Albums settings screen, where "New album" has no photo
  /// to attach yet (unlike the review picker's create flow, which always
  /// creates via `commitAlbumAssignments` alongside an assignment).
  /// Returns the new album's `PHAssetCollection.localIdentifier`.
  func createAlbum(named name: String) async -> Result<String, Error>
}

/// Library changes aren't observed. Live album updates would register a
/// `PHPhotoLibraryChangeObserver` here and call
/// `SessionViewModel.refreshLibraryAlbumsIfLoaded`.
final class PhotoLibraryService: PhotoLibraryServicing {

  func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }

  func currentAuthorizationStatus() -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> AssetBatchSource {
    await Task.detached(priority: .userInitiated) {
      AssetBatchSource(mode: mode, startDate: startDate, excluding: excluding)
    }.value
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

  func fetchAllUserAlbums() async -> [AlbumOption] {
    await Task.detached(priority: .userInitiated) {
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
    }.value
  }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    await Task.detached(priority: .userInitiated) { () -> Set<String> in
      guard
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
          .firstObject
      else { return [] }
      let collections = PHAssetCollection.fetchAssetCollectionsContaining(
        asset, with: .album, options: nil)
      var identifiers: Set<String> = []
      collections.enumerateObjects { collection, _, _ in
        guard collection.assetCollectionSubtype == .albumRegular else { return }
        identifiers.insert(collection.localIdentifier)
      }
      return identifiers
    }.value
  }

  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Set<String>, Error> {
    guard !additions.isEmpty || !removals.isEmpty else { return .success([]) }
    var createdAlbumIDs: Set<String> = []
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
          createdAlbumIDs.insert(request.placeholderForCreatedAssetCollection.localIdentifier)
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
      return .success(createdAlbumIDs)
    } catch {
      return .failure(error)
    }
  }

  func createAlbum(named name: String) async -> Result<String, Error> {
    do {
      var newAlbumID: String?
      try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
          withTitle: name)
        newAlbumID = request.placeholderForCreatedAssetCollection.localIdentifier
      }
      guard let newAlbumID else { return .failure(PhotoLibraryError.albumCreationFailed) }
      return .success(newAlbumID)
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

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> AssetBatchSource {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    AssetBatchSource()
  }

  func totalEligibleAssetCount() -> Int { mockEligibleCount }

  func deleteAssets(_ assets: [PHAsset]) async -> Result<Void, Error> { .success(()) }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> { .success(()) }

  func convertLivePhotoToStill(_ asset: PHAsset) async -> Result<String, Error> {
    .success(asset.localIdentifier)
  }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}

  func fetchAllUserAlbums() async -> [AlbumOption] { [] }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    []
  }

  func commitAlbumAssignments(
    additions: [String: Set<AlbumRef>],
    removals: [String: Set<String>],
    assets: [String: PHAsset]
  ) async -> Result<Set<String>, Error> { .success([]) }

  func createAlbum(named name: String) async -> Result<String, Error> {
    .success(UUID().uuidString)
  }
}
