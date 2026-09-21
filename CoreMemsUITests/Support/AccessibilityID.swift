// CoreMemsUITests/Support/AccessibilityID.swift

/// Mirrors `AccessibilityID` in the app; the UI test bundle can't import the app module.
enum AccessibilityID {
  static let setupStart = "setup.start"
  static let reviewProgress = "review.progress"
  static let reviewCard = "review.card"
  static let reviewDone = "review.done"
  static let reviewTray = "review.tray"
  static let reviewUndo = "review.undo"
  static let reviewDelete = "review.delete"
  static let reviewKeep = "review.keep"
  static let liveBadge = "review.liveBadge"
  static let expandedPhoto = "expanded.photo"
  static let trayRestore = "tray.restore"
  static let pendingConfirm = "pending.confirm"
  static let completion = "completion.root"
}
