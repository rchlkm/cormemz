// CoreMems/Services/PhotoLibraryService+Albums.swift
import Photos

extension PhotoLibraryService {
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

  /// Every folder that holds albums, at any depth; subfolders are referenced by `groupIdentifiers`.
  func fetchAlbumGroups() async -> [AlbumGroup] {
    await Task.detached(priority: .userInitiated) {
      var groups: [AlbumGroup] = []
      PHCollectionList.fetchTopLevelUserCollections(with: nil).enumerateObjects { collection, _, _ in
        guard let folder = collection as? PHCollectionList else { return }
        collectAlbumGroup(folder, into: &groups)
      }
      return groups
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

/// Appends `folder` and its non-empty subfolders to `groups`; returns nil for an empty folder.
@discardableResult
private func collectAlbumGroup(_ folder: PHCollectionList, into groups: inout [AlbumGroup])
  -> AlbumGroup?
{
  guard folder.collectionListType == .folder, let title = folder.localizedTitle else { return nil }
  var albumIdentifiers: [String] = []
  var groupIdentifiers: [String] = []
  let children = PHCollection.fetchCollections(in: folder, options: nil)
  for index in 0..<children.count {
    let child = children.object(at: index)
    if let album = child as? PHAssetCollection {
      if album.assetCollectionSubtype == .albumRegular {
        albumIdentifiers.append(album.localIdentifier)
      }
    } else if let subfolder = child as? PHCollectionList,
      let group = collectAlbumGroup(subfolder, into: &groups)
    {
      groupIdentifiers.append(group.identifier)
    }
  }
  guard !albumIdentifiers.isEmpty || !groupIdentifiers.isEmpty else { return nil }
  let group = AlbumGroup(
    identifier: folder.localIdentifier, name: title, albumIdentifiers: albumIdentifiers,
    groupIdentifiers: groupIdentifiers)
  groups.append(group)
  return group
}
