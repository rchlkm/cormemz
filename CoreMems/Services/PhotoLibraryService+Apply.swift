// CoreMems/Services/PhotoLibraryService+Apply.swift
import Photos

extension PhotoLibraryService {
  func applySessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    guard !changes.isEmpty else { return .success(SessionLibraryResult()) }

    let stills: [String: AssetReplacement]
    do {
      stills = try await conversionReplacements(for: changes)
    } catch {
      return .failure(error)
    }

    var result = SessionLibraryResult()
    var editOutputs: [String: PHContentEditingOutput] = [:]
    var clips: [String: AssetReplacement] = [:]
    for (photoID, staged) in changes.edits {
      #if DEBUG
        if EditFailureSimulation.shouldFail(assetIdentifier: staged.asset.localIdentifier) {
          result.failedEdits[photoID] = .unknown
          continue
        }
      #endif
      switch await editRenderer.output(for: staged.edit, of: staged.asset) {
      case .success(.adjustments(let output)): editOutputs[photoID] = output
      case .success(.clip(let url)):
        clips[photoID] = AssetReplacement(
          original: staged.asset, resourceType: .video, content: .file(url),
          albumIDs: Self.carriedOverAlbumIDs(of: staged.asset, photoID: photoID, in: changes),
          deletesOriginal: staged.edit.deletesOriginal)
      case .failure(let reason): result.failedEdits[photoID] = reason
      }
    }
    let replacements = stills.merging(clips) { still, _ in still }

    do {
      try await PHPhotoLibrary.shared().performChanges {
        var created: [String: PHObjectPlaceholder] = [:]
        for (photoID, replacement) in replacements {
          created[photoID] = replacement.requestCreation()
        }

        for (photoID, output) in editOutputs {
          guard let asset = changes.edits[photoID]?.asset else { continue }
          PHAssetChangeRequest(for: asset).contentEditingOutput = output
        }

        var assetsByExistingAddID: [String: [PHObject]] = [:]
        var assetsByTempID: [String: [PHObject]] = [:]
        var nameByTempID: [String: String] = [:]
        for (photoID, refs) in changes.albumAdditions {
          guard let target = created[photoID] ?? changes.albumAssets[photoID] else { continue }
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
        for (photoID, replacement) in replacements {
          guard let placeholder = created[photoID] else { continue }
          for id in replacement.albumIDs {
            assetsByExistingAddID[id, default: []].append(placeholder)
          }
        }

        // A deleted original's removals are already left out of its replacement's albums.
        var assetsByExistingRemoveID: [String: [PHObject]] = [:]
        for (photoID, ids) in changes.albumRemovals
        where replacements[photoID]?.deletesOriginal != true {
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
          else {
            result.missingAlbumIdentifiers.insert(id)
            continue
          }
          request.addAssets(albumAssets as NSArray)
        }
        for (id, albumAssets) in assetsByExistingRemoveID {
          guard let collection = collectionsByID[id],
            let request = PHAssetCollectionChangeRequest(for: collection)
          else {
            result.missingAlbumIdentifiers.insert(id)
            continue
          }
          request.removeAssets(albumAssets as NSArray)
        }

        // An original is only deleted alongside the asset that replaces it.
        let replaced = replacements.filter { created[$0.key] != nil }
        let deletions =
          changes.deletions + replaced.values.filter(\.deletesOriginal).map(\.original)
        if !deletions.isEmpty {
          PHAssetChangeRequest.deleteAssets(deletions as NSArray)
        }
        let identifiers = created.mapValues(\.localIdentifier)
        result.stillIdentifiers = identifiers.filter { stills[$0.key] != nil }
        result.clipIdentifiers = identifiers.filter { clips[$0.key] != nil }
        let sizes = replaced.compactMapValues(\.contentSize)
        result.stillSizes = sizes.filter { stills[$0.key] != nil }
        result.clipSizes = sizes.filter { clips[$0.key] != nil }
      }
      await editRenderer.discardAll()
      return .success(result)
    } catch {
      return .failure(error)
    }
  }

  /// A still copy of each converted Live Photo, by session photo ID.
  private func conversionReplacements(for changes: SessionLibraryChanges) async throws
    -> [String: AssetReplacement]
  {
    let allowsNetwork = networkAccess.allowsDownloads
    var replacements: [String: AssetReplacement] = [:]
    for (photoID, asset) in changes.conversions {
      guard let resource = Self.stillResource(for: asset) else {
        throw PhotoLibraryError.missingStillResource
      }
      replacements[photoID] = AssetReplacement(
        original: asset, resourceType: .photo,
        content: .data(try await Self.data(for: resource, allowsNetwork: allowsNetwork)),
        albumIDs: Self.carriedOverAlbumIDs(of: asset, photoID: photoID, in: changes))
    }
    return replacements
  }

  /// The albums a copy of `asset` joins: the original's, except those the session removes it from.
  private static func carriedOverAlbumIDs(
    of asset: PHAsset, photoID: String, in changes: SessionLibraryChanges
  ) -> [String] {
    let removed = changes.albumRemovals[photoID] ?? []
    return editableAlbumIDs(containing: asset).filter { !removed.contains($0) }
  }

  /// The edited render when the Live Photo has adjustments, else its original still.
  static func stillResource(for asset: PHAsset) -> PHAssetResource? {
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

  /// Reads a `PHAssetResource`'s raw bytes (pulling from iCloud if the original isn't
  /// on-device and `allowsNetwork`), used here to carry a Live Photo's still component
  /// over as-is so its embedded EXIF survives untouched.
  private static func data(for resource: PHAssetResource, allowsNetwork: Bool) async throws -> Data
  {
    try await withCheckedThrowingContinuation { continuation in
      var data = Data()
      let options = PHAssetResourceRequestOptions()
      options.isNetworkAccessAllowed = allowsNetwork
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
