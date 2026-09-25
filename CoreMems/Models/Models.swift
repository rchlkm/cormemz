// CoreMems/Models/Models.swift
import Foundation

enum ReviewDecision: String, Equatable {
  case undecided
  case keep
  case pendingDelete
  /// Keeps the image as a still photo and deletes the Live Photo original on confirm.
  case convertToStill

  var isKept: Bool { self == .keep || self == .convertToStill }
  /// Decisions that change the library when the session is confirmed.
  var isMarked: Bool { self == .pendingDelete || self == .convertToStill }
}

/// How a session's photos are selected from the library.
enum SelectionMode: String, Equatable, CaseIterable {
  case shuffle
  case recent
  case date

  /// The review screen's caption; `startDateText` fills `.date`.
  func sessionLabel(startDateText: String?) -> String? {
    switch self {
    case .shuffle: return nil
    case .recent: return "Most recent first"
    case .date: return startDateText.map { "From \($0)" }
    }
  }
}

/// A single photo in a review session. In production `assetIdentifier`
/// maps to a `PHAsset.localIdentifier`; `previewImageName`/`previewURL`
/// stand in for whatever thumbnail source you're using in the prototype.
struct SessionPhoto: Identifiable, Equatable {
  let id: String  // stable within-session identifier
  var assetIdentifier: String  // PHAsset.localIdentifier in production
  let previewURL: URL?
  var decision: ReviewDecision = .undecided
  var isFavorite: Bool = false
  var isLivePhoto: Bool = false
  /// Held photos aren't remembered as reviewed, so later sessions offer them again.
  var isHeldForLater: Bool = false
  var dateLabel: String = ""

  /// Only Live Photos can be converted to a still.
  func canReceive(_ decision: ReviewDecision) -> Bool {
    decision != .convertToStill || isLivePhoto
  }
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

/// A real-or-not-yet-real Photos album a photo can be staged into.
/// Modeled as a struct (not an enum) so it's `Codable`/`Hashable` by
/// synthesis; call sites use it like an enum via the two static factories.
struct AlbumRef: Hashable, Codable {
  enum Kind: String, Codable { case existing, pendingNew }
  let kind: Kind
  let identifier: String  // PHAssetCollection.localIdentifier, or a session-local tempID
  let name: String?  // nil for .existing — name comes from the fetched PHAssetCollection

  static func existing(localIdentifier: String) -> AlbumRef {
    AlbumRef(kind: .existing, identifier: localIdentifier, name: nil)
  }
  static func pendingNew(tempID: String, name: String) -> AlbumRef {
    AlbumRef(kind: .pendingNew, identifier: tempID, name: name)
  }
}

/// One album as shown in the picker — real or created-this-session,
/// unified so the UI doesn't need to care which.
struct AlbumOption: Identifiable, Equatable {
  let ref: AlbumRef
  let name: String
  /// For `.existing`, the album's real photo count at fetch time
  /// (`PHAssetCollection.estimatedAssetCount`). For `.pendingNew`, kept
  /// live by `SessionViewModel` as photos are staged into it this
  /// session. `nil` when unknown.
  var assetCount: Int?
  /// `name` folded (case- and diacritic-insensitive) once, so search is a
  /// plain substring check.
  let searchKey: String
  var id: AlbumRef { ref }

  init(ref: AlbumRef, name: String, assetCount: Int? = nil) {
    self.ref = ref
    self.name = name
    self.assetCount = assetCount
    self.searchKey = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
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
