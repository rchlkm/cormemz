// RootView+Previews.swift
import SwiftUI

#if DEBUG

  // 1. TOP: Canvas Previews (What Xcode shows in the preview panel)
  #Preview("1. Access Denied") {
    RootViewContent(vm: .mock(isAccessDenied: true))
  }

  #Preview("2. Home Screen") {
    RootViewContent(vm: .mock(screen: AppScreen.home, eligiblePhotoCount: 1250))
  }

  #Preview("3. Setup Screen") {
    RootViewContent(vm: .mock(screen: AppScreen.setup, maxAvailable: 500))
  }

  #Preview("4. Review Screen") {
    RootViewContent(vm: .mock(screen: AppScreen.review))
  }

  #Preview("5. Pending Review Screen") {
    RootViewContent(vm: .mock(screen: AppScreen.pendingReview))
  }

  #Preview("6. Completion Screen") {
    RootViewContent(vm: .mock(screen: AppScreen.completion, keptCount: 42, deletedCount: 15))
  }

  // 2. BOTTOM: Private Helper (Used ONLY by the #Preview blocks above)
  private struct RootViewPreviewWrapper: View {
    @StateObject private var vm = SessionViewModel()
    let configure: (SessionViewModel) -> Void

    var body: some View {
      RootViewContent(vm: vm)
        .onAppear {
          configure(vm)
        }
    }
  }

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
      }
    }
  }

#endif

