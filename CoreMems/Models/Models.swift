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
    self.searchKey = name.searchFolded
  }
}

/// A Photos folder of albums, as shown by the Photos app's album groups.
struct AlbumGroup: Identifiable, Hashable {
  let identifier: String  // PHCollectionList.localIdentifier
  let name: String
  /// Direct child albums, in the folder's order.
  let albumIdentifiers: [String]
  /// Direct child folders, in the folder's order.
  let groupIdentifiers: [String]
  let searchKey: String
  var id: String { identifier }

  init(
    identifier: String, name: String, albumIdentifiers: [String], groupIdentifiers: [String] = []
  ) {
    self.identifier = identifier
    self.name = name
    self.albumIdentifiers = albumIdentifiers
    self.groupIdentifiers = groupIdentifiers
    self.searchKey = name.searchFolded
  }
}

/// Something the album search can match by name.
protocol Searchable {
  var searchKey: String { get }
}

extension AlbumOption: Searchable {}
extension AlbumGroup: Searchable {}

extension String {
  /// Case- and diacritic-insensitive form used for search matching.
  var searchFolded: String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}

extension Sequence {
  /// Elements keyed by `key`; the first element wins on duplicate keys.
  func indexed<Key: Hashable>(by key: KeyPath<Element, Key>) -> [Key: Element] {
    Dictionary(map { ($0[keyPath: key], $0) }, uniquingKeysWith: { first, _ in first })
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
