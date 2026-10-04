// CoreMemsTests/Support/RecordingPhotoLibrary.swift
import Photos
import UIKit

@testable import CoreMems

enum LibraryTestError: Error {
  case rejected
}

/// A photo library double that serves `assets`, logs the calls that touch the
/// library, and answers applies from configurable outcomes.
final class RecordingPhotoLibrary: PhotoLibraryServicing {
  enum Event: Equatable {
    case storageSize(Set<String>)
    case apply
  }

  var assets: [PHAsset] = []
  var authorizationStatus: PHAuthorizationStatus = .authorized
  /// Bytes reported per asset identifier; unlisted assets report zero.
  var storageSizes: [String: Int64] = [:]
  /// Bytes of the still copy made for each original asset identifier; unlisted assets report zero.
  var stillSizes: [String: Int64] = [:]
  /// Bytes of the trimmed clip made for each original asset identifier; unlisted assets report zero.
  var clipSizes: [String: Int64] = [:]
  /// When set, every apply returns this instead of succeeding.
  var applyFailure: Error?
  /// Stubbed answer for `randomAssetDate()`, defaulting to the first asset's date.
  var stubbedRandomDate: Date?
  /// Identifiers of the albums each apply reports as created.
  var createdAlbumIDs: Set<String> = []
  /// Session photo IDs whose still copy the apply fails to produce.
  var photoIDsWithoutStill: Set<String> = []
  /// Asset identifiers that can't be shown without a download.
  var assetsNeedingDownload: Set<String> = []
  /// Session photo IDs whose edit the apply reports as failed to render, for `editFailureReason`.
  var photoIDsWithFailedEdit: Set<String> = []
  var editFailureReason = EditFailureReason.unknown
  /// Each edit handed to `prepareEdit`, with its asset identifier, in order.
  private(set) var preparedEdits: [(assetID: String, edit: MediaEdit)] = []
  /// Asset identifiers whose original isn't on the device.
  var assetsWithoutLocalOriginal: Set<String> = []

  /// The source handed to the most recent session.
  private(set) var lastSource: FakeAssetSource?
  /// The media types passed to the most recent `makeAssetSource` call.
  private(set) var lastMediaTypes: Set<MediaType>?
  private(set) var events: [Event] = []
  private(set) var appliedChanges: [SessionLibraryChanges] = []

  func requestAuthorization() async -> PHAuthorizationStatus { authorizationStatus }
  func currentAuthorizationStatus() -> PHAuthorizationStatus { authorizationStatus }

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, albumIdentifier: String?,
    mediaTypes: Set<MediaType>, excluding: Set<String>
  ) async -> any AssetBatching {
    let source = FakeAssetSource(assets: assets.filter { !excluding.contains($0.localIdentifier) })
    lastSource = source
    lastMediaTypes = mediaTypes
    return source
  }

  func totalEligibleAssetCount() -> Int { assets.count }

  func isDisplayableWithoutNetwork(_ asset: PHAsset) async -> Bool {
    !assetsNeedingDownload.contains(asset.localIdentifier)
  }

  func hasLocalOriginal(_ asset: PHAsset) -> Bool {
    !assetsWithoutLocalOriginal.contains(asset.localIdentifier)
  }

  func randomAssetDate() async -> Date? { stubbedRandomDate ?? assets.first?.creationDate }

  /// Treats `assets`, in the order given, as the library's own order — independent
  /// of whatever order a session fetched them in via `makeAssetSource`.
  func neighborAssets(of assetIdentifier: String, before: Int, after: Int) async -> [PHAsset] {
    guard let index = assets.firstIndex(where: { $0.localIdentifier == assetIdentifier }) else {
      return []
    }
    let lower = max(0, index - before)
    let upper = min(assets.count - 1, index + after)
    guard lower <= upper else { return [] }
    return Array(assets[lower...upper])
  }

  func storageSize(of assets: [PHAsset]) async -> Int64? {
    events.append(.storageSize(Set(assets.map(\.localIdentifier))))
    return assets.reduce(0) { $0 + (storageSizes[$1.localIdentifier] ?? 0) }
  }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> {
    .success(())
  }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}

  var albums: [AlbumOption] = []

  func fetchAllUserAlbums() async -> [AlbumOption] { albums }

  var albumGroups: [AlbumGroup] = []

  func fetchAlbumGroups() async -> [AlbumGroup] { albumGroups }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    []
  }

  func prepareEdit(_ edit: MediaEdit, for asset: PHAsset) {
    preparedEdits.append((asset.localIdentifier, edit))
  }

  func applySessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    events.append(.apply)
    appliedChanges.append(changes)
    if let applyFailure { return .failure(applyFailure) }
    let stills = changes.conversions
      .filter { !photoIDsWithoutStill.contains($0.key) }
      .mapValues { "still-\($0.localIdentifier)" }
    let sizes = changes.conversions
      .filter { stills[$0.key] != nil }
      .mapValues { stillSizes[$0.localIdentifier] ?? 0 }
    let clips = changes.edits
      .filter { $0.value.edit.trimRange != nil && !photoIDsWithFailedEdit.contains($0.key) }
      .mapValues { "clip-\($0.asset.localIdentifier)" }
    let trimmedSizes = changes.edits
      .filter { clips[$0.key] != nil }
      .mapValues { clipSizes[$0.asset.localIdentifier] ?? 0 }
    return .success(SessionLibraryResult(
      stillIdentifiers: stills, stillSizes: sizes, clipIdentifiers: clips, clipSizes: trimmedSizes,
      createdAlbumIDs: createdAlbumIDs,
      failedEdits: changes.edits.keys
        .filter { photoIDsWithFailedEdit.contains($0) }
        .reduce(into: [:]) { reasons, id in reasons[id] = editFailureReason }))
  }

  func createAlbum(named name: String) async -> Result<String, Error> {
    .success(UUID().uuidString)
  }

  func observeLibraryChanges(_ handler: @escaping () -> Void) -> AnyObject {
    NSObject()
  }
}
