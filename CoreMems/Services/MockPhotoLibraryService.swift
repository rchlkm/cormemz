// CoreMems/Services/MockPhotoLibraryService.swift
import Photos
import UIKit

/// In-memory fake used by SwiftUI previews and the Dev Panel preview
/// states, so the UI can be built/reviewed without a device photo
/// library or Photos permission prompts.
final class MockPhotoLibraryService: PhotoLibraryServicing {
  var mockEligibleCount: Int = 200
  var mockAuthStatus: PHAuthorizationStatus = .authorized
  var mockAlbums: [AlbumOption] = []
  var mockAlbumGroups: [AlbumGroup] = []

  func requestAuthorization() async -> PHAuthorizationStatus { mockAuthStatus }
  func currentAuthorizationStatus() -> PHAuthorizationStatus { mockAuthStatus }

  func makeAssetSource(
    mode: SelectionMode, startDate: Date?, excluding: Set<String>
  ) async -> any AssetBatching {
    // Previews/mocks never touch real PHAssets — callers should
    // prefer 'SessionViewModel''s mock photo generator instead.
    AssetBatchSource()
  }

  func totalEligibleAssetCount() -> Int { mockEligibleCount }

  func randomAssetDate() async -> Date? { Date() }

  func neighborAssets(of assetIdentifier: String, before: Int, after: Int) async -> [PHAsset] { [] }

  func storageSize(of assets: [PHAsset]) async -> Int64? { 0 }

  func setFavorite(_ asset: PHAsset, isFavorite: Bool) async -> Result<Void, Error> { .success(()) }

  func presentLimitedLibraryPicker(from viewController: UIViewController) {}

  func fetchAllUserAlbums() async -> [AlbumOption] { mockAlbums }

  func fetchAlbumGroups() async -> [AlbumGroup] { mockAlbumGroups }

  func fetchAlbumIdentifiers(containingAssetIdentifier identifier: String) async -> Set<String> {
    []
  }

  func commitSessionChanges(_ changes: SessionLibraryChanges) async
    -> Result<SessionLibraryResult, Error>
  {
    .success(
      SessionLibraryResult(stillIdentifiers: changes.conversions.mapValues(\.localIdentifier)))
  }

  func createAlbum(named name: String) async -> Result<String, Error> {
    .success(UUID().uuidString)
  }
}
