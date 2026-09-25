// CoreMems/Views/Components/SpaceCleanedCard.swift
import SwiftUI

extension Int64 {
  var fileSizeText: String { formatted(.byteCount(style: .file)) }
}

/// Space freed, split into deleted photos and Live Photo conversions, with a total.
struct SpaceCleanedCard: View {
  let deletedBytes: Int64
  let convertedBytes: Int64

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Space cleaned")
        .font(.headline)
      LabeledContent("Deleted photos", value: deletedBytes.fileSizeText)
      LabeledContent("Live Photo conversions", value: convertedBytes.fileSizeText)
      Divider()
      LabeledContent("Total", value: (deletedBytes + convertedBytes).fileSizeText)
        .fontWeight(.semibold)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
  }
}

#Preview {
  SpaceCleanedCard(deletedBytes: 1_840_000_000, convertedBytes: 310_000_000)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
