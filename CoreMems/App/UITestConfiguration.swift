// CoreMems/App/UITestConfiguration.swift
import SwiftUI

/// Launch-time switches for UI tests. Everything here is compiled out of release builds.
enum UITestConfiguration {
  static let launchArgument = "-uiTesting"

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
    private static let mockLibraryPhotoCount = 20

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
      let reviewedStore = ReviewedPhotosStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("ui-test-reviewed-\(UUID().uuidString).json"))
      return SessionViewModel(
        library: library,
        persistence: MockSessionPersistence(),
        haptics: MockHapticsService(),
        statsStore: MockLifetimeStatsService(),
        pinnedAlbumsStore: MockPinnedAlbumsStore(),
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
