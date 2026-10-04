// CoreMems/Views/Components/SpaceCleanedCard.swift
import SwiftUI

extension Int64 {
  var fileSizeText: String { formatted(.byteCount(style: .file)) }
}

/// Space freed, split into deleted photos, Live Photo conversions and trimmed videos, with a
/// total. Sources that freed nothing are left out.
struct SpaceCleanedCard: View {
  let deletedBytes: Int64
  let convertedBytes: Int64
  let trimmedBytes: Int64

  private var sources: [(label: String, bytes: Int64)] {
    [
      ("Deleted photos", deletedBytes),
      ("Live Photo conversions", convertedBytes),
      ("Trimmed videos", trimmedBytes),
    ].filter { $0.bytes > 0 }
  }

  private var totalBytes: Int64 { deletedBytes + convertedBytes + trimmedBytes }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Space cleaned")
        .font(.headline)
      ForEach(sources, id: \.label) { source in
        LabeledContent(source.label, value: source.bytes.fileSizeText)
      }
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
