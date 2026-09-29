// CoreMems/Views/Components/BrowseControlBar.swift
import SwiftUI

/// Back / delete / keep action row shown beneath the browse card
/// stack. Purely presentational — the parent decides what each action
/// actually does to session state.
struct BrowseControlBar: View {
  let canGoBack: Bool
  let onGoBack: () -> Void
  let onDelete: () -> Void
  let onKeep: () -> Void

  var body: some View {
    HStack(spacing: 22) {
      Button(action: onGoBack) { Image(systemName: "arrow.uturn.backward") }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .tinted(.secondary)))
        .accessibilityIdentifier(AccessibilityID.browseGoBack)
        .disabled(!canGoBack)
      Button(action: onDelete) { Image(systemName: "trash") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(Decision.pendingDelete.tint)))
        .accessibilityIdentifier(AccessibilityID.browseDelete)
      Button(action: onKeep) { Image(systemName: "checkmark") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(Decision.keep.tint)))
        .accessibilityIdentifier(AccessibilityID.browseKeep)
    }
    .padding(.vertical, 18)
    .padding(.bottom, 12)
  }
}
