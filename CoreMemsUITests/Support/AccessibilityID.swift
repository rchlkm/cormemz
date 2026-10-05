// CoreMemsUITests/Support/AccessibilityID.swift

/// Mirrors `AccessibilityID` in the app; the UI test bundle can't import the app module.
enum AccessibilityID {
  static let setupStart = "setup.start"
  static let browseProgress = "browse.progress"
  static let browseCard = "browse.card"
  static let browseDone = "browse.done"
  static let browseTray = "browse.tray"
  static let browseGoBack = "browse.goBack"
  static let browseDelete = "browse.delete"
  static let browseKeep = "browse.keep"
  static let liveBadge = "browse.liveBadge"
  static let browsePeekToggle = "browse.peekToggle"
  static let browsePeekDelete = "browse.peekDelete"
  static let browsePeekRestore = "browse.peekRestore"
  static let expandedPhoto = "expanded.photo"
  static let editStart = "edit.start"
  static let editRotate = "edit.rotate"
  static let editCancel = "edit.cancel"
  static let editDone = "edit.done"
  static let trayRestore = "tray.restore"
  static let gridPhoto = "grid.photo"
  static let photoViewer = "photoViewer.root"
  static let photoViewerUndo = "photoViewer.undo"
  static let applyConfirm = "apply.confirm"
  static let completion = "completion.root"
  static let emojiPickerField = "emojiPicker.field"
}
