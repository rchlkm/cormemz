// CoreMems/Views/Components/ReviewControlBar.swift
import SwiftUI

/// Undo / delete / keep action row shown beneath the review card
/// stack. Purely presentational — the parent decides what each action
/// actually does to session state.
struct ReviewControlBar: View {
  let canUndo: Bool
  let onUndo: () -> Void
  let onDelete: () -> Void
  let onKeep: () -> Void

  var body: some View {
    HStack(spacing: 22) {
      Button(action: onUndo) { Image(systemName: "arrow.uturn.backward") }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .tinted(.secondary)))
        .accessibilityIdentifier(AccessibilityID.reviewUndo)
        .disabled(!canUndo)
      Button(action: onDelete) { Image(systemName: "trash") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(.red)))
        .accessibilityIdentifier(AccessibilityID.reviewDelete)
      Button(action: onKeep) { Image(systemName: "checkmark") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(.green)))
        .accessibilityIdentifier(AccessibilityID.reviewKeep)
    }
    .padding(.vertical, 18)
    .padding(.bottom, 12)
  }
}
