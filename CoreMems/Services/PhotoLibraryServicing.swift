// CoreMems/Services/PhotoLibraryServicing.swift
import Photos
import UIKit

enum PhotoLibraryError: LocalizedError {
  case missingStillResource
  case creationFailed
  case albumCreationFailed

  var errorDescription: String? {
    switch self {
    case .missingStillResource:
      return "This Live Photo has no still-image component to extract."
    case .creationFailed:
      return "The still photo couldn't be created."
    case .albumCreationFailed:
      return "The album couldn't be created."
    }
  }
}

/// A staged edit and the asset it's written to.
struct AssetEdit {
  let asset: PHAsset
  let edit: MediaEdit
}

/// Everything a session changes in the library. `albumAssets` maps a session photo ID
/// to its `PHAsset` for the album changes.
struct SessionLibraryChanges {
  var deletions: [PHAsset] = []
  /// Live Photos to replace with a still copy, by session photo ID.
  var conversions: [String: PHAsset] = [:]
  var albumAdditions: [String: Set<AlbumRef>] = [:]
  var albumRemovals: [String: Set<String>] = [:]
  var albumAssets: [String: PHAsset] = [:]
  /// Edits to write, by session photo ID: in place, or as a new clip for a trim.
  var edits: [String: AssetEdit] = [:]

  var isEmpty: Bool {
    deletions.isEmpty && conversions.isEmpty && albumAdditions.isEmpty && albumRemovals.isEmpty
      && edits.isEmpty
  }
}

struct SessionLibraryResult {
  /// Local identifier of each still copy, by session photo ID.
  var stillIdentifiers: [String: String] = [:]
  /// File size in bytes of each still copy, by session photo ID.
  var stillSizes: [String: Int64] = [:]
  /// Local identifier of each trimmed video's new clip, by session photo ID.
  var clipIdentifiers: [String: String] = [:]
  /// Local identifiers of albums created for former `.pendingNew` refs.
  var createdAlbumIDs: Set<String> = []
  /// Identifiers of staged album adds/removes that silently no-op'd because the album no
  /// longer exists (deleted, or renamed away, since the photo was tagged for it).
  var missingAlbumIdentifiers: Set<String> = []
  /// Why each edit left out was left out, by session photo ID.
  var failedEdits: [String: EditFailureReason] = [:]
}

/// Photos permission state and the limited-library picker.
protocol PhotoAuthorization {
  func requestAuthorization() async -> PHAuthorizationStatus
  func currentAuthorizationStatus() -> PHAuthorizationStatus
  /// Presents Apple's native limited-library picker so a Limited
  /// Photos Access user can grant access to more photos in-app.
  func presentLimitedLibraryPicker(from viewController: UIViewController)
}

/// Read access to the library's eligible (image-only) assets.
protocol AssetLibrary {
  /// Opens the eligible (image-only) assets for `mode` as a lazily loaded stream,
  /// skipping the local identifiers in 'excluding'. `startDate` applies to `.date`,
  /// `albumIdentifier` to `.album`, `mediaTypeFilter` narrows further (e.g. screenshots only).
  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, albumIdentifier: String?,
    mediaTypeFilter: MediaTypeFilter, excluding: Set<String>
  ) async -> any AssetBatching
  func totalEligibleAssetCount() -> Int
  /// A random eligible asset's creation date; `nil` if the library has no eligible assets.
  func randomAssetDate() async -> Date?
  /// Up to `before` eligible (image) assets immediately older and `after` immediately
  /// newer than the asset with `assetIdentifier`, in the library's own creation-date
  /// order, plus that asset itself — true library neighbors, independent of any
  /// session's fetch order. Empty if the asset can't be found.
  func neighborAssets(of assetIdentifier: String, before: Int, after: Int) async -> [PHAsset]
  /// Whether a browse-sized image of `asset` can be produced without downloading anything.
  func isDisplayableWithoutNetwork(_ asset: PHAsset) async -> Bool
  /// Whether the file a Live Photo conversion reads is on the device.
  func hasLocalOriginal(_ asset: PHAsset) -> Bool
}

/// User album lookup and creation.
protocol AlbumLibrary {
  /// Every user-created album (names and counts only); `.albumRegular`
  /// excludes smart albums like Favorites. Runs off the main thread.
  func fetchAllUserAlbums() async -> [AlbumOption]
  /// Top-level Photos folders and their regular albums; folders with none are omitted.
  /// Runs off the main thread.
  func fetchAlbumGroups() async -> [AlbumGroup]
  /// Identifiers of every user album containing the asset. A direct lookup
  /// for one asset, so it stays fast at any library size. Runs off the main thread.
  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String>
  /// Creates a real, empty Photos album with the given title — used by
  /// the Pinned Albums settings screen, where "New album" has no photo
  /// to attach yet (unlike the browse picker's create flow, which always
  /// creates via `applySessionChanges` alongside an assignment).
  /// Returns the new album's `PHAssetCollection.localIdentifier`.
  func createAlbum(named name: String) async -> Result<String, Error>
  /// Calls `handler` whenever the Photos library changes (an album added, renamed, or
  /// deleted, on this device or via iCloud sync) — including changes made while the app
  /// was suspended. `handler` may be called on any thread. The returned token keeps
  /// observing until deallocated.
  func observeLibraryChanges(_ handler: @escaping () -> Void) -> AnyObject
}

/// Changes written to the library, and the size lookup that precedes deleting.
protocol LibraryEditing {
  /// Combined stored size in bytes of every resource (photo, paired video,
  /// edits) of `assets`; `nil` if the system doesn't report sizes. Read it
  /// before deleting, since a deleted asset's resources are gone.
  func storageSize(of assets: [PHAsset]) async -> Int64?
  /// Writes the favorite flag to the Photos library via
  /// `PHAssetChangeRequest`. Callers should treat `.failure` as a
  /// signal to roll back any optimistic UI update.
  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error>
  /// Starts rendering `edit` in the background, so applying it later only has to write it.
  func prepareEdit(_ edit: MediaEdit, for asset: PHAsset)
  /// Applies everything a session changes in the library as one transaction: still
  /// copies of converted Live Photos (the originals are deleted), edits, trimmed clips, album
  /// changes, and deletions. Deleted photos move to Recently Deleted. The user sees one system prompt, and
  /// either all of it happens or none of it does; an edit that can't be rendered is left out
  /// rather than failing the rest.
  func applySessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
}

/// The full PhotoKit wrapper; consumers depend on the narrowest protocol they use.
typealias PhotoLibraryServicing = PhotoAuthorization & AssetLibrary & AlbumLibrary & LibraryEditing
