// CoreMems/Views/Components/ReviewControlBar.swift
import SwiftUI

/// Back / delete / keep action row shown beneath the review card
/// stack. Purely presentational — the parent decides what each action
/// actually does to session state.
struct ReviewControlBar: View {
  let canGoBack: Bool
  let onGoBack: () -> Void
  let onDelete: () -> Void
  let onKeep: () -> Void

  var body: some View {
    HStack(spacing: 22) {
      Button(action: onGoBack) { Image(systemName: "arrow.uturn.backward") }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .tinted(.secondary)))
        .accessibilityIdentifier(AccessibilityID.reviewGoBack)
        .disabled(!canGoBack)
      Button(action: onDelete) { Image(systemName: "trash") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(ReviewDecision.pendingDelete.tint)))
        .accessibilityIdentifier(AccessibilityID.reviewDelete)
      Button(action: onKeep) { Image(systemName: "checkmark") }
        .buttonStyle(IconButtonStyle(size: .large, surface: .tinted(ReviewDecision.keep.tint)))
        .accessibilityIdentifier(AccessibilityID.reviewKeep)
    }
    .padding(.vertical, 18)
    .padding(.bottom, 12)
  }
}
