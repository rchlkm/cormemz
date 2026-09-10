import Foundation

enum ReviewDecision: String, Equatable {
  case undecided
  case keep
  case pendingDelete
}

/// A single photo in a review session. In production `assetIdentifier`
/// maps to a `PHAsset.localIdentifier`; `previewImageName`/`previewURL`
/// stand in for whatever thumbnail source you're using in the prototype.
struct SessionPhoto: Identifiable, Equatable {
  let id: String  // stable within-session identifier
  let assetIdentifier: String  // PHAsset.localIdentifier in production
  let previewURL: URL?
  var decision: ReviewDecision = .undecided
  var isFavorite: Bool = false
  var tagFolderIDs: Set<String> = []
  var dateLabel: String = ""
}

/// One entry in the full pending-delete history for the session.
struct DecisionHistoryEntry {
  let photoIndex: Int
  let previousDecision: ReviewDecision
  let newDecision: ReviewDecision
  /// True if this decision was the one that advanced the review index
  /// (i.e. it happened via swipe/keep/delete on the current card, not
  /// via a Tray restore of an earlier photo).
  let advancedIndex: Bool
}

struct Folder: Identifiable, Equatable {
  let id: String
  var name: String
  var emoji: String
}

enum SessionLifecycleState: Equatable {
  case idle
  case active
  case pendingReview
  case completed
}

struct ReviewSession {
  let id: UUID = UUID()
  var requestedSize: Int
  var photos: [SessionPhoto]
  var currentIndex: Int = 0
  var lifecycleState: SessionLifecycleState = .idle
}
