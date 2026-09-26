// CoreMems/App/UITestConfiguration.swift
import SwiftUI

/// Launch-time switches for UI tests. Everything here is compiled out of release builds.
enum UITestConfiguration {
  static let launchArgument = "-uiTesting"
  static let largeAlbumLibraryArgument = "-uiTestingLargeAlbumLibrary"

  static var isActive: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains(launchArgument)
    #else
      false
    #endif
  }
}

#if DEBUG
  extension UITestConfiguration {
    private static let mockLibraryPhotoCount = 2000
    private static let largeLibraryAlbumCount = 300
    private static let largeLibraryFolderCount = 30
    private static let largeLibraryPinnedCount = 6

    private static var usesLargeAlbumLibrary: Bool {
      ProcessInfo.processInfo.arguments.contains(largeAlbumLibraryArgument)
    }

    /// Albums and folders sized like a big real library; half the albums sit in folders.
    private static func seedLargeAlbumLibrary(
      _ library: MockPhotoLibraryService, pinnedStore: MockPinnedAlbumsStore
    ) {
      let albums = (0..<largeLibraryAlbumCount).map {
        AlbumOption(
          ref: .existing(localIdentifier: "album-\($0)"), name: "Album \($0)", assetCount: $0)
      }
      let foldered = albums.prefix(albums.count / 2)
      let groups = (0..<largeLibraryFolderCount).map { folder in
        AlbumGroup(
          identifier: "folder-\(folder)", name: "Folder \(folder)",
          albumIdentifiers: foldered.enumerated()
            .filter { $0.offset % largeLibraryFolderCount == folder }
            .map(\.element.ref.identifier))
      }
      library.mockAlbums = albums
      library.mockAlbumGroups = groups
      pinnedStore.identifiers = albums.prefix(largeLibraryPinnedCount).map(\.ref.identifier)
    }

    /// Starts every launch from a clean, onboarded state.
    static func resetPersistedState() {
      guard isActive, let domain = Bundle.main.bundleIdentifier else { return }
      UserDefaults.standard.removePersistentDomain(forName: domain)
      UserDefaults.standard.set(true, forKey: RootView.hasOnboardedKey)
    }

    /// A view model backed by in-memory doubles, so no photos prompt appears and
    /// nothing outlives the launch.
    static func makeViewModel() -> SessionViewModel {
      let library = MockPhotoLibraryService()
      library.mockEligibleCount = mockLibraryPhotoCount
      let pinnedStore = MockPinnedAlbumsStore()
      if usesLargeAlbumLibrary { seedLargeAlbumLibrary(library, pinnedStore: pinnedStore) }
      let reviewedStore = ReviewedPhotosStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("ui-test-reviewed-\(UUID().uuidString).json"))
      return SessionViewModel(
        library: library,
        persistence: MockSessionPersistence(),
        haptics: MockHapticsService(),
        statsStore: MockLifetimeStatsService(),
        pinnedAlbumsStore: pinnedStore,
        reviewedPhotosStore: reviewedStore)
    }
  }
#endif

extension View {
  /// Identifies a container for UI tests while keeping its children individually
  /// addressable, and exposes `value` to them. A no-op outside UI tests.
  @ViewBuilder
  func uiTestContainer(_ identifier: String, value: String = "") -> some View {
    if UITestConfiguration.isActive {
      accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(value)
    } else {
      self
    }
  }
}
