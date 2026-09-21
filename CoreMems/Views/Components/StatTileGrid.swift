// CoreMems/Views/Components/StatTileGrid.swift
import SwiftUI

struct StatTileItem: Identifiable {
  let label: String
  let value: String
  let systemImage: String
  /// Outcome color; nil is neutral.
  var tint: Color? = nil
  var id: String { label }
}

/// Two-column grid of number tiles.
struct StatTileGrid: View {
  let items: [StatTileItem]

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
      ForEach(items) { tile($0) }
    }
  }

  private func tile(_ item: StatTileItem) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: item.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(item.tint ?? Color.secondary)
      Text(item.value)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .monospacedDigit()
      Text(item.label)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .cardBackground()
    .accessibilityElement(children: .combine)
  }
}

extension View {
  func cardBackground() -> some View {
    background(
      Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  StatTileGrid(items: [
    StatTileItem(label: "Kept", value: "1,206", systemImage: "checkmark", tint: ReviewDecision.keep.tint),
    StatTileItem(
      label: "Deleted", value: "274", systemImage: "trash", tint: ReviewDecision.pendingDelete.tint),
  ])
  .padding()
  .background(Color(uiColor: .systemGroupedBackground))
}
