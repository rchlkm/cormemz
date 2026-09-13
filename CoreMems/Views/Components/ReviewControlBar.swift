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
      CircleIconButton(
        system: "arrow.uturn.backward", tint: .secondary, size: 48, disabled: !canUndo,
        action: onUndo)
      CircleIconButton(system: "trash", tint: .red, size: 64, action: onDelete)
      CircleIconButton(system: "checkmark", tint: .green, size: 64, action: onKeep)
    }
    .padding(.vertical, 18)
    .padding(.bottom, 12)
  }
}
