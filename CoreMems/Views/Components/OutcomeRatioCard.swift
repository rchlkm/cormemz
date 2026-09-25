// CoreMems/Views/Components/OutcomeRatioCard.swift
import SwiftUI

/// Bar and legend splitting reviewed photos into kept, converted, and deleted.
struct OutcomeRatioCard: View {
  let kept: Int
  let converted: Int
  let deleted: Int

  private struct Segment: Identifiable {
    let label: String
    let count: Int
    let color: Color
    var id: String { label }
  }

  private static let barSpacing: CGFloat = 3

  private var segments: [Segment] {
    [
      Segment(label: "Kept", count: kept, color: ReviewDecision.keep.tint),
      Segment(label: "Converted", count: converted, color: ReviewDecision.convertToStill.tint),
      Segment(label: "Deleted", count: deleted, color: ReviewDecision.pendingDelete.tint),
    ]
  }

  private var total: Int { segments.reduce(0) { $0 + $1.count } }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Kept vs deleted vs converted")
        .font(.headline)
      bar
      HStack(spacing: 16) {
        ForEach(segments) { legendItem($0) }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
    .accessibilityElement(children: .combine)
  }

  private var bar: some View {
    GeometryReader { proxy in
      let visible = segments.filter { $0.count > 0 }
      let gaps = CGFloat(max(visible.count - 1, 0)) * Self.barSpacing
      let available = proxy.size.width - gaps
      HStack(spacing: Self.barSpacing) {
        if visible.isEmpty {
          Capsule().fill(Color(uiColor: .tertiarySystemFill))
        }
        ForEach(visible) { segment in
          Capsule()
            .fill(segment.color)
            .frame(width: available * CGFloat(segment.count) / CGFloat(total))
        }
      }
    }
    .frame(height: 14)
  }

  private func legendItem(_ segment: Segment) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(segment.color)
        .frame(width: 8, height: 8)
      Text(segment.label)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Text(percentString(segment))
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func percentString(_ segment: Segment) -> String {
    guard total > 0 else { return "–" }
    return (Double(segment.count) / Double(total)).formatted(
      .percent.precision(.fractionLength(0)))
  }
}

#Preview {
  OutcomeRatioCard(kept: 1_144, converted: 62, deleted: 274)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
