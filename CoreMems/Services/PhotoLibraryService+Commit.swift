// CoreMems/Services/PhotoLibraryService+Commit.swift
import Photos

extension PhotoLibraryService {
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
        result.stillSizes = stillData.filter { stills[$0.key] != nil }.mapValues { Int64($0.count) }
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
}
