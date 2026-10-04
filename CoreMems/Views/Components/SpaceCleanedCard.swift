// CoreMems/Views/Components/SpaceCleanedCard.swift
import SwiftUI

extension Int64 {
  var fileSizeText: String { formatted(.byteCount(style: .file)) }
}

/// Space freed, split into deleted photos, Live Photo conversions and trimmed videos, with a total.
struct SpaceCleanedCard: View {
  let deletedBytes: Int64
  let convertedBytes: Int64
  let trimmedBytes: Int64

  private var totalBytes: Int64 { deletedBytes + convertedBytes + trimmedBytes }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Space cleaned")
        .font(.headline)
      LabeledContent("Deleted photos", value: deletedBytes.fileSizeText)
      LabeledContent("Live Photo conversions", value: convertedBytes.fileSizeText)
      LabeledContent("Trimmed videos", value: trimmedBytes.fileSizeText)
      Divider()
      LabeledContent("Total", value: totalBytes.fileSizeText)
        .fontWeight(.semibold)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
  }
}

#Preview {
  SpaceCleanedCard(
    deletedBytes: 1_840_000_000, convertedBytes: 310_000_000, trimmedBytes: 95_000_000)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
