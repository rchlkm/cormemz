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

  #Preview("4. Browse Screen") {
    RootViewContent(vm: .mock(screen: .browse, photos: SessionViewModel.mockPhotos(count: 8)))
  }

  #Preview("5. Apply Changes Screen") {
    let photos = applyChangesFixture()
    RootViewContent(
      vm: .mock(screen: .pendingChanges, photos: photos, currentIndex: photos.count))
  }

  #Preview("6. Completion Screen") {
    RootViewContent(
      vm: .mock(screen: .completion, photos: keptPhotosFixture(count: 42), deletedCount: 15))
  }

  /// A mix of kept and pending-delete photos, as if a browse pass just
  /// finished — feeds the Apply Changes preview's grid.
  private func applyChangesFixture() -> [SessionPhoto] {
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
    @State private var showSettings = false

    private var settingsView: some View {
      SettingsView(
        checkInInterval: $vm.checkInInterval,
        includesDecidedPhotos: $vm.includesDecidedPhotos,
        networkPolicy: $vm.networkPolicy,
        isLowDataModeActive: vm.isLowDataModeActive,
        defaultSessionMode: $vm.defaultSessionMode,
        decidedPhotoCount: vm.decidedPhotoCount,
        libraryPhotoCount: vm.eligiblePhotoCount,
        onResetDecidedPhotos: { vm.resetDecidedPhotos() },
        pinnedAlbums: vm.pinnedAlbums,
        recentAlbumIDs: vm.recentAlbumIDs,
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
            NavigationStack {
              SetupView(
                maxAvailable: vm.maxAvailable,
                isStarting: vm.isStartingSession,
                defaultMode: vm.defaultSessionMode,
                onPickRandomDate: { await vm.randomAssetDate() },
                onPrepareAlbumPicker: { await vm.preloadLibraryAlbums() },
                onOpenSettings: { showSettings = true },
                onStart: { mode, startDate, album, mediaTypeFilter in
                  Task {
                    await vm.startSession(
                      mode: mode, startDate: startDate, album: album, mediaTypeFilter: mediaTypeFilter)
                  }
                },
                onRefresh: {
                  vm.screen = .home
                  Task { await vm.refreshLibrary() }
                },
                quickAccessAlbums: vm.quickAccessAlbums,
                libraryAlbums: vm.libraryAlbums,
                libraryAlbumGroups: vm.libraryAlbumGroups,
                recentAlbumIDs: vm.recentAlbumIDs,
                pinnedAlbums: vm.pinnedAlbums
              )
              .toolbar(.hidden, for: .navigationBar)
              .navigationDestination(isPresented: $showSettings) { settingsView }
            }
          case .browse:
            BrowseView(vm: vm)
          case .pendingChanges:
            ApplyChangesView(vm: vm)
          case .completion:
            CompletionView(
              keptCount: vm.keptCount,
              deletedCount: vm.deletedCount,
              albumAssignedCount: vm.albumAssignedCount,
              missingAlbumCount: vm.missingAlbumCount,
              convertedCount: vm.convertedLivePhotoCount,
              editedCount: vm.editedCount,
              deletedBytes: vm.deletedBytes,
              convertedBytesSaved: vm.convertedBytesSaved,
              decidedPhotoCount: vm.decidedPhotoCount,
              libraryPhotoCount: vm.eligiblePhotoCount,
              onAgain: { vm.resetForAnotherSession() }
            )
          }
        }
      }
    }
  }

#endif
