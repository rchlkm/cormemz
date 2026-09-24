// CoreMems/Previews/SessionViewModel+Mock.swift
import Foundation
import Photos

extension SessionViewModel {
  /// Placeholder photos for previews and for demos on an empty library.
  static func mockPhotos(count: Int) -> [SessionPhoto] {
    (0..<count).map { i in
      let date = Calendar.current.date(byAdding: .day, value: -i * 11, to: Date()) ?? Date()
      return SessionPhoto(
        id: "mock-\(i)",
        assetIdentifier: "mock-asset-\(i)",
        previewURL: URL(string: "https://picsum.photos/seed/coremems-\(i)/420/580"),
        isFavorite: i % 4 == 1,
        isLivePhoto: i % 5 == 2,
        dateLabel: cardDateFormatter.string(from: date)
      )
    }
  }
}

#if DEBUG
  extension SessionViewModel {
    /// Configures a `SessionViewModel` for SwiftUI Previews. Every
    /// parameter maps directly onto published state. `maxAvailable` and
    /// `keptCount` are computed properties and can't be set directly —
    /// drive them by passing `eligiblePhotoCount` and a `photos` array
    /// (e.g. via `mockPhotos(count:)`) instead.
    static func mock(
      screen: AppScreen = .home,
      isAccessDenied: Bool = false,
      eligiblePhotoCount: Int = 100,
      photos: [SessionPhoto] = [],
      currentIndex: Int = 0,
      deletedCount: Int = 0
    ) -> SessionViewModel {
      let vm = SessionViewModel()
      vm.screen = screen
      vm.authorizationStatus = isAccessDenied ? .denied : .authorized
      vm.eligiblePhotoCount = eligiblePhotoCount
      vm.photos = photos
      vm.currentIndex = currentIndex
      vm.deletedCount = deletedCount
      return vm
    }
  }
#endif
