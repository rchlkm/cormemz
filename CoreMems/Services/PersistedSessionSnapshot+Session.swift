// CoreMems/Services/PersistedSessionSnapshot+Session.swift
import Foundation

extension PersistedSessionSnapshot {
  init(
    photos: [SessionPhoto], currentIndex: Int, history: [DecisionHistoryEntry],
    albumStaging: AlbumStaging
  ) {
    self.init(
      photoIDs: photos.map(\.id),
      decisions: photos.map(\.decision.rawValue),
      assetIdentifiers: photos.map(\.assetIdentifier),
      currentIndex: currentIndex,
      historyPhotoIndices: history.map(\.photoIndex),
      historyPrevious: history.map(\.previousDecision.rawValue),
      historyNew: history.map(\.newDecision.rawValue),
      historyAdvanced: history.map(\.advancedIndex),
      albumAdditions: albumStaging.additions,
      albumRemovals: albumStaging.removals,
      pendingNewAlbumRefs: albumStaging.pendingNewAlbums.map(\.ref)
    )
  }

  var restoredPhotos: [SessionPhoto] {
    (0..<min(photoIDs.count, decisions.count, assetIdentifiers.count)).map { i in
      var photo = SessionPhoto(id: photoIDs[i], assetIdentifier: assetIdentifiers[i], previewURL: nil)
      photo.decision = ReviewDecision(rawValue: decisions[i]) ?? .undecided
      return photo
    }
  }

  var restoredHistory: [DecisionHistoryEntry] {
    let count = min(
      historyPhotoIndices.count, historyPrevious.count, historyNew.count, historyAdvanced.count)
    return (0..<count).map { i in
      DecisionHistoryEntry(
        photoIndex: historyPhotoIndices[i],
        previousDecision: ReviewDecision(rawValue: historyPrevious[i]) ?? .undecided,
        newDecision: ReviewDecision(rawValue: historyNew[i]) ?? .undecided,
        advancedIndex: historyAdvanced[i]
      )
    }
  }

  var restoredAlbumStaging: AlbumStaging {
    AlbumStaging(
      additions: albumAdditions, removals: albumRemovals,
      pendingNewAlbums: pendingNewAlbumRefs.map { AlbumOption(ref: $0, name: $0.name ?? "") })
  }
}
