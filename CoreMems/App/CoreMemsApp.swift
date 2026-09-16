// CoreMems/App/CoreMemsApp.swift
import Photos
import SwiftUI

@main
struct CoreMemsApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}

struct RootView: View {
  @StateObject private var vm = SessionViewModel()
  @AppStorage("cm_hasOnboarded") private var hasOnboarded = false
  @State private var showConfirm = false
  @Environment(\.scenePhase) private var scenePhase

  /// True until the user has granted access at least once. While
  /// true, show the full permission-request Home screen.
  private var needsOnboarding: Bool {
    !hasOnboarded || vm.authorizationStatus == .notDetermined
  }

  var body: some View {
    ZStack {
      if vm.isAccessDenied {
        DeniedAccessView(onOpenSettings: {
          vm.manageAccess(presentingFrom: UIApplication.shared.rootViewController)
        })
      } else if needsOnboarding {
        HomeView(
          photoCount: vm.eligiblePhotoCount,
          limitedAccess: vm.isLimitedAccess,
          emptyLibrary: vm.emptyLibrary,
          onStart: {
            Task {
              await vm.checkAuthorization()
              if vm.authorizationStatus == .authorized || vm.authorizationStatus == .limited {
                hasOnboarded = true
                vm.screen = .setup
              }
            }
          },
          onManageAccess: {
            vm.manageAccess(presentingFrom: UIApplication.shared.rootViewController)
          }
        )
      } else {
        switch vm.screen {
        case .home:
          HomeSplashView(photoCount: vm.eligiblePhotoCount) {
            vm.screen = .setup
          }
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
    .task {
      vm.refreshAuthorizationStatus()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        vm.refreshAuthorizationStatus()
      }
    }
    .onChange(of: vm.screen) { _, newScreen in
      // Covers the retry-from-the-sheet path, where `confirmDeletion`
      // is re-entered via `retryAlbumAssignments` instead of the
      // sheet's own `onConfirm` closure.
      if newScreen == .completion {
        showConfirm = false
      }
    }
    .sheet(isPresented: $showConfirm) {
      ConfirmSheetView(
        count: vm.pendingItems.count,
        favoritesCount: vm.pendingItems.filter(\.isFavorite).count,
        isDeleting: vm.isDeleting || vm.isFlushingAlbums,
        errorMessage: vm.deletionError,
        albumErrorMessage: vm.albumAssignmentError,
        onCancel: { showConfirm = false },
        onConfirm: { Task { await vm.confirmDeletion() } },
        onRetryAlbums: { vm.retryAlbumAssignments() }
      )
      .presentationDetents([.medium])
    }
  }
}
