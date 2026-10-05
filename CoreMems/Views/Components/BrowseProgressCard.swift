// CoreMems/Views/Components/BrowseProgressCard.swift
import SwiftUI

/// How much of the library, photos and videos, has been kept.
struct BrowseProgressCard: View {
  let kept: Int
  let total: Int

  /// 0...1; zero when the library is empty.
  static func fraction(kept: Int, total: Int) -> Double {
    guard total > 0 else { return 0 }
    return min(max(Double(kept) / Double(total), 0), 1)
  }

  private var fraction: Double { Self.fraction(kept: kept, total: total) }

  private var shownKept: Int { min(kept, total) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Reviewed in library")
          .font(.headline)
        Spacer()
        Text(total > 0 ? fraction.formatted(.percent.precision(.fractionLength(0))) : "–")
          .font(.headline)
          .monospacedDigit()
      }
      bar
      Text("\(shownKept.formatted()) of \(total.formatted()) photos and videos")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
    .accessibilityElement(children: .combine)
  }

  private var bar: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Color(uiColor: .tertiarySystemFill))
        Capsule()
          .fill(Color.secondary)
          .frame(width: proxy.size.width * fraction)
      }
    }
    .frame(height: 14)
  }
}

#Preview {
  BrowseProgressCard(kept: 1_206, total: 3_100)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
