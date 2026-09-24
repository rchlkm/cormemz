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

/// Everything a session changes in the library. `albumAssets` maps a session photo ID
/// to its `PHAsset` for the album changes.
struct SessionLibraryChanges {
  var deletions: [PHAsset] = []
  /// Live Photos to replace with a still copy, by session photo ID.
  var conversions: [String: PHAsset] = [:]
  var albumAdditions: [String: Set<AlbumRef>] = [:]
  var albumRemovals: [String: Set<String>] = [:]
  var albumAssets: [String: PHAsset] = [:]

  var isEmpty: Bool {
    deletions.isEmpty && conversions.isEmpty && albumAdditions.isEmpty && albumRemovals.isEmpty
  }
}

struct SessionLibraryResult {
  /// Local identifier of each still copy, by session photo ID.
  var stillIdentifiers: [String: String] = [:]
  /// Local identifiers of albums created for former `.pendingNew` refs.
  var createdAlbumIDs: Set<String> = []
}

/// PhotoKit wrapper
protocol PhotoLibraryServicing {
  func requestAuthorization() async -> PHAuthorizationStatus
  func currentAuthorizationStatus() -> PHAuthorizationStatus

  /// Opens the eligible (image-only) assets for `mode` as a lazily loaded stream,
  /// skipping the local identifiers in 'excluding'. `startDate` applies to `.date`.
  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> any AssetBatching
  func totalEligibleAssetCount() -> Int
  /// A random eligible asset's creation date; `nil` if the library has no eligible assets.
  func randomAssetDate() async -> Date?

  /// Combined stored size in bytes of every resource (photo, paired video,
  /// edits) of `assets`; `nil` if the system doesn't report sizes. Read it
  /// before deleting, since a deleted asset's resources are gone.
  func storageSize(of assets: [PHAsset]) async -> Int64?
  /// Writes the favorite flag to the Photos library via
  /// `PHAssetChangeRequest`. Callers should treat `.failure` as a
  /// signal to roll back any optimistic UI update.
  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error>
  /// Presents Apple's native limited-library picker so a Limited
  /// Photos Access user can grant access to more photos in-app.
  func presentLimitedLibraryPicker(from viewController: UIViewController)

  /// Every user-created album (names and counts only); `.albumRegular`
  /// excludes smart albums like Favorites. Runs off the main thread.
  func fetchAllUserAlbums() async -> [AlbumOption]
  /// Identifiers of every user album containing the asset. A direct lookup
  /// for one asset, so it stays fast at any library size. Runs off the main thread.
  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String>
  /// Applies everything a session changes in the library as one transaction: still
  /// copies of converted Live Photos (the originals are deleted), album changes, and
  /// deletions. Deleted photos move to Recently Deleted. The user sees one system
  /// prompt, and either all of it happens or none of it does.
  func commitSessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  /// Creates a real, empty Photos album with the given title — used by
  /// the Pinned Albums settings screen, where "New album" has no photo
  /// to attach yet (unlike the review picker's create flow, which always
  /// creates via `commitSessionChanges` alongside an assignment).
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
  ) async -> any AssetBatching {
    await Task.detached(priority: .userInitiated) {
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

  /// PhotoKit has no public size API; `PHAssetResource` exposes it through the
  /// `fileSize` key, so the lookup is guarded against the key going away.
  func storageSize(of assets: [PHAsset]) async -> Int64? {
    await Task.detached(priority: .userInitiated) { () -> Int64? in
      let sizeKey = "fileSize"
      var total: Int64 = 0
      for asset in assets {
        for resource in PHAssetResource.assetResources(for: asset) {
          guard resource.responds(to: NSSelectorFromString(sizeKey)) else { return nil }
          total += (resource.value(forKey: sizeKey) as? NSNumber)?.int64Value ?? 0
        }
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

  func commitSessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    guard !changes.isEmpty else { return .success(SessionLibraryResult()) }

    var stillData: [String: Data] = [:]
    do {
      for (photoID, asset) in changes.conversions {
        guard let resource = Self.stillResource(for: asset) else {
          return .failure(PhotoLibraryError.missingStillResource)
        }
        stillData[photoID] = try await Self.data(for: resource)
      }
    } catch {
      return .failure(error)
    }

    var inheritedAlbumIDs: [String: [String]] = [:]
    for (photoID, asset) in changes.conversions {
      let removed = changes.albumRemovals[photoID] ?? []
      inheritedAlbumIDs[photoID] = Self.editableAlbumIDs(containing: asset)
        .filter { !removed.contains($0) }
    }

    var result = SessionLibraryResult()
    do {
      try await PHPhotoLibrary.shared().performChanges {
        var stills: [String: PHObjectPlaceholder] = [:]
        for (photoID, asset) in changes.conversions {
          guard let data = stillData[photoID] else { continue }
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .photo, data: data, options: nil)
          request.creationDate = asset.creationDate
          request.location = asset.location
          request.isFavorite = asset.isFavorite
          if let placeholder = request.placeholderForCreatedAsset {
            stills[photoID] = placeholder
          }
        }

        var assetsByExistingAddID: [String: [PHObject]] = [:]
        var assetsByTempID: [String: [PHObject]] = [:]
        var nameByTempID: [String: String] = [:]
        for (photoID, refs) in changes.albumAdditions {
          guard let target = stills[photoID] ?? changes.albumAssets[photoID] else { continue }
          for ref in refs {
            switch ref.kind {
            case .existing:
              assetsByExistingAddID[ref.identifier, default: []].append(target)
            case .pendingNew:
              assetsByTempID[ref.identifier, default: []].append(target)
              nameByTempID[ref.identifier] = ref.name
            }
          }
        }
        for (photoID, albumIDs) in inheritedAlbumIDs {
          guard let still = stills[photoID] else { continue }
          for id in albumIDs {
            assetsByExistingAddID[id, default: []].append(still)
          }
        }

        // A converted photo's removals are already left out of its inherited albums.
        var assetsByExistingRemoveID: [String: [PHObject]] = [:]
        for (photoID, ids) in changes.albumRemovals where changes.conversions[photoID] == nil {
          guard let asset = changes.albumAssets[photoID] else { continue }
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
          result.createdAlbumIDs.insert(request.placeholderForCreatedAssetCollection.localIdentifier)
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

        // An original is only deleted alongside the still that replaces it.
        let replaced = changes.conversions.filter { stills[$0.key] != nil }.map(\.value)
        let deletions = changes.deletions + replaced
        if !deletions.isEmpty {
          PHAssetChangeRequest.deleteAssets(deletions as NSArray)
        }
        result.stillIdentifiers = stills.mapValues(\.localIdentifier)
      }
      return .success(result)
    } catch {
      return .failure(error)
    }
  }

  /// The edited render when the Live Photo has adjustments, else its original still.
  private static func stillResource(for asset: PHAsset) -> PHAssetResource? {
    let resources = PHAssetResource.assetResources(for: asset)
    return resources.first { $0.type == .fullSizePhoto } ?? resources.first { $0.type == .photo }
  }

  /// Identifiers of the user albums holding `asset` that accept new photos; the same
  /// album set the picker shows.
  private static func editableAlbumIDs(containing asset: PHAsset) -> [String] {
    var ids: [String] = []
    PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
      .enumerateObjects { collection, _, _ in
        guard collection.assetCollectionSubtype == .albumRegular,
          collection.canPerform(.addContent)
        else { return }
        ids.append(collection.localIdentifier)
      }
    return ids
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
  ) async -> any AssetBatching {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    AssetBatchSource()
  }

  func totalEligibleAssetCount() -> Int { mockEligibleCount }

  func randomAssetDate() async -> Date? { Date() }

  func storageSize(of assets: [PHAsset]) async -> Int64? { 0 }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> { .success(()) }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}

  func fetchAllUserAlbums() async -> [AlbumOption] { [] }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    []
  }

  func commitSessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    .success(
      SessionLibraryResult(stillIdentifiers: changes.conversions.mapValues(\.localIdentifier)))
  }

  func createAlbum(named name: String) async -> Result<String, Error> {
    .success(UUID().uuidString)
  }
}
