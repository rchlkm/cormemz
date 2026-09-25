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
