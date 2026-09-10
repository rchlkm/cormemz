import UIKit

/// `PHPhotoLibrary.presentLimitedLibraryPicker(from:)` needs a real
/// `UIViewController` to present from. SwiftUI doesn't hand you one
/// directly, so this walks the active scene's key window.
extension UIApplication {
  var foregroundActiveScene: UIWindowScene? {
    connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
  }

  var rootViewController: UIViewController? {
    foregroundActiveScene?.windows.first(where: \.isKeyWindow)?.rootViewController
  }
}
