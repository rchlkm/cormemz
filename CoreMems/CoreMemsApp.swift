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
  @State private var showConfirm = false
  @State private var showDevPanel = false
  @Environment(\.scenePhase) private var scenePhase

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
            limitedAccess: vm.isLimitedAccess,
            emptyLibrary: vm.emptyLibrary,
            onStart: { vm.screen = .setup },
            onManageAccess: {
              vm.manageAccess(presentingFrom: UIApplication.shared.rootViewController)
            }
          )
        case .setup:
          SetupView(maxAvailable: vm.maxAvailable) { size in
            Task { await vm.startSession(requestedSize: size) }
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
            onHome: { vm.exitToHome() },
            onAgain: { vm.resetForAnotherSession() }
          )
        }
      }

      // Dev panel — preview-only affordance, strip before shipping.
      VStack {
        HStack {
          Spacer()
          DevPanelView(vm: vm, isOpen: $showDevPanel)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        Spacer()
      }
    }
    .task {
      // Read status on launch without prompting — the actual
      // request happens lazily the first time the user taps
      // "Start a session" (see `SessionViewModel.startSession`).
      vm.refreshAuthorizationStatus()
    }
    .onChange(of: scenePhase) { _, newPhase in
      // Picks up changes made in Settings (grant/deny/limited
      // selection) the moment the user comes back to the app.
      if newPhase == .active {
        vm.refreshAuthorizationStatus()
      }
    }
    .sheet(isPresented: $showConfirm) {
      ConfirmSheetView(
        count: vm.pendingItems.count,
        favoritesCount: vm.pendingItems.filter(\.isFavorite).count,
        isDeleting: vm.isDeleting,
        errorMessage: vm.deletionError,
        onCancel: { showConfirm = false },
        onConfirm: {
          Task {
            await vm.confirmDeletion()
            showConfirm = false
          }
        }
      )
      .presentationDetents([.medium])
    }
  }
}
