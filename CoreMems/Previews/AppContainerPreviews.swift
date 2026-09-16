// CoreMems/Previews/AppContainerPreviews.swift
import SwiftUI

#if DEBUG

  #Preview("1. Access Denied") {
    RootViewContent(vm: .mock(isAccessDenied: true))
  }

  #Preview("2. Home Screen") {
    RootViewContent(vm: .mock(screen: .home, eligiblePhotoCount: 1250))
  }

  #Preview("3. Setup Screen") {
    RootViewContent(vm: .mock(screen: .setup, eligiblePhotoCount: 500))
  }

  #Preview("4. Review Screen") {
    RootViewContent(vm: .mock(screen: .review, photos: SessionViewModel.mockPhotos(count: 8)))
  }

  #Preview("5. Pending Review Screen") {
    let photos = pendingReviewFixture()
    RootViewContent(
      vm: .mock(screen: .pendingReview, photos: photos, currentIndex: photos.count))
  }

  #Preview("6. Completion Screen") {
    RootViewContent(
      vm: .mock(screen: .completion, photos: keptPhotosFixture(count: 42), deletedCount: 15))
  }

  /// A mix of kept and pending-delete photos, as if a review pass just
  /// finished — feeds the Pending Review preview's grid.
  private func pendingReviewFixture() -> [SessionPhoto] {
    var photos = SessionViewModel.mockPhotos(count: 10)
    for i in photos.indices {
      photos[i].decision = i % 3 == 0 ? .pendingDelete : .keep
    }
    return photos
  }

  /// Photos already marked `.keep`, matching the ViewModel's real
  /// post-deletion state where only kept photos remain in `photos`.
  private func keptPhotosFixture(count: Int) -> [SessionPhoto] {
    var photos = SessionViewModel.mockPhotos(count: count)
    for i in photos.indices { photos[i].decision = .keep }
    return photos
  }

  /// Renders the same screen switch as `RootView`, but driven by a
  /// directly-configured `SessionViewModel.mock(...)` instead of live
  /// PhotoKit/persistence state, so each screen can be canvased in
  /// isolation without onboarding or a populated device library.
  private struct RootViewContent: View {
    @ObservedObject var vm: SessionViewModel
    @State private var showConfirm = false

    var body: some View {
      ZStack {
        if vm.isAccessDenied {
          DeniedAccessView(onOpenSettings: {
            vm.manageAccess(presentingFrom: UIApplication.shared.rootViewController)
          })
        } else {
          switch vm.screen {
          case .home:
            HomeView(
              photoCount: vm.eligiblePhotoCount,
              limitedAccess: vm.isLimitedAccess,
              emptyLibrary: vm.emptyLibrary,
              onStart: { vm.screen = .setup },
              onManageAccess: {
                vm.manageAccess(presentingFrom: UIApplication.shared.rootViewController)
              }
            )
          case .setup:
            SetupView(maxAvailable: vm.maxAvailable, checkInInterval: $vm.checkInInterval) {
              mode, startDate in
              Task { await vm.startSession(mode: mode, startDate: startDate) }
            } onBack: {
              vm.screen = .home
            }
          case .review:
            ReviewView(vm: vm)
          case .pendingReview:
            PendingReviewView(vm: vm, showConfirm: $showConfirm)
          case .completion:
            CompletionView(
              keptCount: vm.keptCount,
              deletedCount: vm.deletedCount,
              albumAssignedCount: vm.albumAssignedCount,
              lifetimeStats: vm.lifetimeStats,
              onAgain: { vm.resetForAnotherSession() }
            )
          }
        }
      }
    }
  }

#endif
