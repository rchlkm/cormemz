// CoreMems/App/CoreMemsApp.swift
import Photos
import SwiftUI

@main
struct CoreMemsApp: App {
  init() {
    #if DEBUG
      UITestConfiguration.resetPersistedState()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}

struct RootView: View {
  static let hasOnboardedKey = "cm_hasOnboarded"

  @StateObject private var vm = RootView.makeViewModel()
  @AppStorage(RootView.hasOnboardedKey) private var hasOnboarded = false
  @State private var showSettings = false
  @Environment(\.scenePhase) private var scenePhase

  private static func makeViewModel() -> SessionViewModel {
    #if DEBUG
      if UITestConfiguration.isActive { return UITestConfiguration.makeViewModel() }
    #endif
    return SessionViewModel()
  }

  /// True until the user has granted access at least once. While
  /// true, show the full permission-request Home screen.
  private var needsOnboarding: Bool {
    !hasOnboarded || vm.authorizationStatus == .notDetermined
  }

  private var settingsView: some View {
    SettingsView(
      checkInInterval: $vm.checkInInterval,
      includesReviewedPhotos: $vm.includesReviewedPhotos,
      reviewedPhotoCount: vm.reviewedPhotoCount,
      libraryPhotoCount: vm.eligiblePhotoCount,
      onResetReviewedPhotos: { vm.resetReviewedPhotos() },
      pinnedAlbums: vm.pinnedAlbums,
      pinnedAlbumOrder: vm.orderedPinnedAlbumIDs,
      lifetimeStats: vm.lifetimeStats,
      onClearLifetimeStats: { vm.clearLifetimeStats() }
    )
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
          NavigationStack {
            SetupView(
              maxAvailable: vm.maxAvailable,
              isStarting: vm.isStartingSession,
              onPickRandomDate: { await vm.randomAssetDate() },
              onOpenSettings: { showSettings = true }
            ) {
              mode, startDate in
              Task { await vm.startSession(mode: mode, startDate: startDate) }
            } onRefresh: {
              vm.screen = .home
              Task { await vm.refreshLibrary() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSettings) { settingsView }
          }
        case .review:
          ReviewView(vm: vm)
        case .pendingReview:
          PendingReviewView(vm: vm)
        case .completion:
          CompletionView(
            keptCount: vm.keptCount,
            deletedCount: vm.deletedCount,
            albumAssignedCount: vm.albumAssignedCount,
            convertedCount: vm.convertedLivePhotoCount,
            reviewedPhotoCount: vm.reviewedPhotoCount,
            libraryPhotoCount: vm.eligiblePhotoCount,
            onAgain: { vm.resetForAnotherSession() }
          )
          .uiTestContainer(AccessibilityID.completion)
        }
      }
    }
    .task {
      vm.refreshAuthorizationStatus()
      #if DEBUG
        PersistedStateDump.runIfEnabled(reason: "launch")
      #endif
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      #if DEBUG
        if newPhase == .background { PersistedStateDump.runIfEnabled(reason: "background") }
      #endif
      if newPhase == .active {
        vm.refreshAuthorizationStatus()
        // Albums may have changed in Photos while backgrounded; brief
        // inactive blips (e.g. Control Center) don't count.
        if oldPhase == .background {
          Task { await vm.refreshLibraryAlbumsIfLoaded() }
        }
      }
    }
  }
}
