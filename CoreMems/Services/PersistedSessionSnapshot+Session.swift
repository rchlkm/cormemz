// CoreMems/Services/PersistedSessionSnapshot+Session.swift
import Foundation

extension PersistedSessionSnapshot {
  init(deck: SessionDeck, albumStaging: AlbumStaging) {
    self.init(
      photoIDs: deck.photos.map(\.id),
      decisions: deck.photos.map(\.decision.rawValue),
      assetIdentifiers: deck.photos.map(\.assetIdentifier),
      currentIndex: deck.currentIndex,
      historyPhotoIndices: deck.history.map(\.photoIndex),
      historyPrevious: deck.history.map(\.previousDecision.rawValue),
      historyNew: deck.history.map(\.newDecision.rawValue),
      historyAdvanced: deck.history.map(\.advancedIndex),
      albumAdditions: albumStaging.additions,
      albumRemovals: albumStaging.removals,
      heldPhotoIDs: deck.photos.filter(\.isHeldForLater).map(\.id),
      pendingNewAlbumRefs: albumStaging.pendingNewAlbums.map(\.ref)
    )
  }

  var restoredDeck: SessionDeck {
    SessionDeck(photos: restoredPhotos, currentIndex: currentIndex, history: restoredHistory)
  }

  private var restoredPhotos: [SessionPhoto] {
    (0..<min(photoIDs.count, decisions.count, assetIdentifiers.count)).map { i in
      var photo = SessionPhoto(id: photoIDs[i], assetIdentifier: assetIdentifiers[i], previewURL: nil)
      photo.decision = ReviewDecision(rawValue: decisions[i]) ?? .undecided
      photo.isHeldForLater = heldPhotoIDs.contains(photoIDs[i])
      return photo
    }
  }

  private var restoredHistory: [DecisionHistoryEntry] {
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
