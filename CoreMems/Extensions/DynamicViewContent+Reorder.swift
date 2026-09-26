// CoreMems/Extensions/DynamicViewContent+Reorder.swift
import SwiftUI

extension DynamicViewContent {
  /// Drag-to-reorder without an Edit button. Handles show when the enclosing list is in edit
  /// mode (see `AlbumSearchList.isReorderable`). `onReorder` receives `ids` in their new order.
  func reorderable(
    _ isEnabled: Bool, ids: [String], onReorder: @escaping ([String]) -> Void
  ) -> some View {
    onMove(
      perform: isEnabled
        ? { source, destination in
          var reordered = ids
          reordered.move(fromOffsets: source, toOffset: destination)
          onReorder(reordered)
        } : nil
    )
  }
}
