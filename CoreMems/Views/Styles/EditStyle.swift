// CoreMems/Views/Styles/EditStyle.swift
import SwiftUI

/// How a staged edit is shown across browse, tray, and stats screens.
enum EditStyle {
  static let title = "Edited"
  static let symbol = "slider.horizontal.3"
  static let tint = Color.orange
}

extension View {
  /// The frosted surface the editor's controls sit on.
  func editorGlass<S: Shape>(in shape: S) -> some View {
    glassEffect(.regular.interactive(), in: shape)
  }

  /// A text button on a frosted capsule, for the editor's Cancel and Done.
  func editorPill(tint: Color = .white) -> some View {
    fontWeight(.semibold)
      .foregroundStyle(tint)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .editorGlass(in: Capsule())
  }
}

extension MediaEdit {
  /// What the edit changes, for labels like "Kept · Rotated 90°".
  var summary: String {
    var parts: [String] = []
    if quarterTurns != 0 { parts.append("Rotated \(quarterTurns * 90)°") }
    if trimRange != nil { parts.append("Trimmed") }
    return parts.joined(separator: ", ")
  }
}

extension EditFailureReason {
  var message: String {
    switch self {
    case .needsDownload:
      return "The original is in iCloud and downloads are paused. Connect to Wi‑Fi or allow downloads, then try again."
    case .declined:
      return "Photos asked for permission and it was declined. Try again and allow it."
    case .unknown:
      return "Photos couldn't save this edit."
    }
  }
}
