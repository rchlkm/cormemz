// CoreMems/Models/SessionChangePlan.swift
import Photos

/// What confirming a session changes in the library, worked out from the deck.
struct SessionChangePlan {
  let deletions: [SessionPhoto]
  /// Marked Live Photos that still have their asset.
  let conversions: [SessionPhoto]
  let keptCount: Int
  /// Photos with an edit to write.
  let editedCount: Int
  let changes: SessionLibraryChanges

  init(deck: SessionDeck, assets: [String: PHAsset], staging: AlbumStaging) {
    deletions = deck.pendingItems
    conversions = deck.pendingConversions.filter { assets[$0.id] != nil }
    keptCount = deck.keptCount

    // Album changes on a photo that's being deleted are moot.
    let (additions, removals) = staging.changes(excludingPhotoIDs: Set(deletions.map(\.id)))
    let convertedIDs = Set(conversions.map(\.id))
    changes = SessionLibraryChanges(
      deletions: deletions.compactMap { assets[$0.id] },
      conversions: assets.filter { convertedIDs.contains($0.key) },
      albumAdditions: additions, albumRemovals: removals, albumAssets: assets,
      edits: deck.pendingEdits.reduce(into: [:]) { byID, photo in
        guard let asset = assets[photo.id], let edit = photo.activeEdit else { return }
        byID[photo.id] = AssetEdit(asset: asset, edit: edit)
      })
    editedCount = changes.edits.count
  }
}
