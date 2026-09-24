// CoreMemsTests/Support/RecordingPhotoLibrary.swift
import Photos
import UIKit

@testable import CoreMems

enum LibraryTestError: Error {
  case rejected
}

/// A photo library double that serves `assets`, logs the calls that touch the
/// library, and answers commits from configurable outcomes.
final class RecordingPhotoLibrary: PhotoLibraryServicing {
  enum Event: Equatable {
    case storageSize(Set<String>)
    case commit
  }

  var assets: [PHAsset] = []
  var authorizationStatus: PHAuthorizationStatus = .authorized
  /// Bytes reported per asset identifier; unlisted assets report zero.
  var storageSizes: [String: Int64] = [:]
  /// When set, every commit returns this instead of succeeding.
  var commitFailure: Error?
  /// Stubbed answer for `randomAssetDate()`, defaulting to the first asset's date.
  var stubbedRandomDate: Date?
  /// Session photo IDs whose still copy the commit fails to produce.
  var photoIDsWithoutStill: Set<String> = []

  /// The source handed to the most recent session.
  private(set) var lastSource: FakeAssetSource?
  private(set) var events: [Event] = []
  private(set) var committedChanges: [SessionLibraryChanges] = []

  func requestAuthorization() async -> PHAuthorizationStatus { authorizationStatus }
  func currentAuthorizationStatus() -> PHAuthorizationStatus { authorizationStatus }

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> any AssetBatching {
    let source = FakeAssetSource(assets: assets.filter { !excluding.contains($0.localIdentifier) })
    lastSource = source
    return source
  }

  func totalEligibleAssetCount() -> Int { assets.count }

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

  func fetchAllUserAlbums() async -> [AlbumOption] { [] }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    []
  }

  func commitSessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    events.append(.commit)
    committedChanges.append(changes)
    if let commitFailure { return .failure(commitFailure) }
    let stills = changes.conversions
      .filter { !photoIDsWithoutStill.contains($0.key) }
      .mapValues { "still-\($0.localIdentifier)" }
    return .success(SessionLibraryResult(stillIdentifiers: stills))
  }

  func createAlbum(named name: String) async -> Result<String, Error> {
    .success(UUID().uuidString)
  }
}
