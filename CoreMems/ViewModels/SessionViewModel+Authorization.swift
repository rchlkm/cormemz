// CoreMems/ViewModels/SessionViewModel+Authorization.swift
import Photos
import UIKit

extension SessionViewModel {
  /// Dev-panel override OR real `.limited` status — either should show
  /// the "you've shared a limited set of photos" banner.
  var isLimitedAccess: Bool { limitedAccess || authorizationStatus == .limited }

  /// Denied-access state.
  var isAccessDenied: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }

  /// Checks current status and, if the user has never been asked,
  /// triggers the system prompt. Call this before any flow that needs
  /// real photos — `startSession` does this automatically.
  @discardableResult
  func checkAuthorization() async -> PHAuthorizationStatus {
    var status = library.currentAuthorizationStatus()
    if status == .notDetermined {
      status = await library.requestAuthorization()
    }
    authorizationStatus = status
    return status
  }

  /// Re-reads status without prompting — call when the app returns to
  /// the foreground (e.g. after the user grants access in Settings or
  /// changes their Limited selection) so the UI updates on its own.
  func refreshAuthorizationStatus() {
    authorizationStatus = library.currentAuthorizationStatus()
    eligiblePhotoCount = library.totalEligibleAssetCount()
  }

  /// Single entry point for every "Manage access" affordance in the UI
  /// (Home's limited-access banner, the denied-access recovery screen).
  /// Routes to the right system surface based on current status.
  func manageAccess(presentingFrom viewController: UIViewController?) {
    switch authorizationStatus {
    case .limited:
      guard let viewController else { return }
      library.presentLimitedLibraryPicker(from: viewController)
    case .denied, .restricted:
      openSettings()
    case .notDetermined:
      Task { await checkAuthorization() }
    case .authorized:
      break
    @unknown default:
      break
    }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    Task { @MainActor in
      UIApplication.shared.open(url)
    }
  }
}
