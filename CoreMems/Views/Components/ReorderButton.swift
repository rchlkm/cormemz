// CoreMems/Views/Components/ReorderButton.swift
import SwiftUI

/// Toggles the enclosing list's edit mode, where `reorderable` rows show their drag handles.
/// Rows only swipe outside edit mode.
struct ReorderButton: View {
  @Environment(\.editMode) private var editMode

  private var isReordering: Bool { editMode?.wrappedValue.isEditing == true }

  var body: some View {
    Button(isReordering ? "Done" : "Reorder") {
      editMode?.wrappedValue = isReordering ? .inactive : .active
    }
  }
}
