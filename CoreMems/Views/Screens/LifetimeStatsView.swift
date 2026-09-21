// CoreMems/Views/Screens/LifetimeStatsView.swift
import SwiftUI

/// Every lifetime stat in one place. Pushed from the top of Settings.
struct LifetimeStatsView: View {
  let stats: LifetimeSessionStats
  let reviewedPhotoCount: Int
  let libraryPhotoCount: Int
  let onClear: () -> Void

  @State private var showClearConfirmation = false

  private struct RatioSegment: Identifiable {
    let label: String
    let count: Int
    let color: Color
    var id: String { label }
  }

  private struct SpaceRow: Identifiable {
    let label: String
    let bytes: Int64
    var id: String { label }
  }

  private var tiles: [StatTileItem] {
    [
      StatTileItem(
        label: "Sessions", value: stats.sessionsCompleted.formatted(),
        systemImage: "clock.arrow.circlepath"),
      StatTileItem(
        label: "Kept", value: stats.keptUnchanged.formatted(), systemImage: "checkmark.circle",
        tint: ReviewDecision.keep.tint),
      StatTileItem(label: "Reviewed", value: stats.totalReviewed.formatted(), systemImage: "eye"),
      StatTileItem(
        label: "Live Photos converted", value: stats.livePhotosConverted.formatted(),
        systemImage: "livephoto", tint: ReviewDecision.convertToStill.tint),
    ]
  }

  private var ratioSegments: [RatioSegment] {
    [
      RatioSegment(label: "Kept", count: stats.keptUnchanged, color: ReviewDecision.keep.tint),
      RatioSegment(
        label: "Converted", count: stats.livePhotosConverted,
        color: ReviewDecision.convertToStill.tint),
      RatioSegment(
        label: "Deleted", count: stats.totalDeleted, color: ReviewDecision.pendingDelete.tint),
    ]
  }

  private var ratioTotal: Int { ratioSegments.reduce(0) { $0 + $1.count } }

  private var spaceRows: [SpaceRow] {
    [
      SpaceRow(label: "Deleted photos", bytes: stats.bytesDeleted),
      SpaceRow(label: "Live Photo conversions", bytes: stats.bytesSavedByConversion),
    ]
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        hero
        StatTileGrid(items: tiles)
        ratioCard
        ReviewProgressCard(reviewed: reviewedPhotoCount, total: libraryPhotoCount)
        spaceCard
        footer
        clearButton
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Lifetime Stats")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var hero: some View {
    VStack(spacing: 6) {
      Text(stats.totalDeleted.formatted())
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .monospacedDigit()
      Text("photos deleted")
        .font(.headline)
      Text("\(byteString(stats.bytesCleaned)) cleaned")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .cardBackground()
    .accessibilityElement(children: .combine)
  }

  private var ratioCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Kept vs deleted vs converted")
        .font(.headline)
      ratioBar
      HStack(spacing: 16) {
        ForEach(ratioSegments) { legendItem($0) }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
    .accessibilityElement(children: .combine)
  }

  private var ratioBar: some View {
    GeometryReader { proxy in
      let segments = ratioSegments.filter { $0.count > 0 }
      let gaps = CGFloat(max(segments.count - 1, 0)) * Self.ratioBarSpacing
      let available = proxy.size.width - gaps
      HStack(spacing: Self.ratioBarSpacing) {
        if segments.isEmpty {
          Capsule().fill(Color(uiColor: .tertiarySystemFill))
        }
        ForEach(segments) { segment in
          Capsule()
            .fill(segment.color)
            .frame(width: available * CGFloat(segment.count) / CGFloat(ratioTotal))
        }
      }
    }
    .frame(height: 14)
  }

  private func legendItem(_ segment: RatioSegment) -> some View {
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

  private func percentString(_ segment: RatioSegment) -> String {
    guard ratioTotal > 0 else { return "–" }
    return (Double(segment.count) / Double(ratioTotal)).formatted(
      .percent.precision(.fractionLength(0)))
  }

  private var spaceCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Space cleaned")
        .font(.headline)
      ForEach(spaceRows) { row in
        LabeledContent(row.label, value: byteString(row.bytes))
      }
      Divider()
      LabeledContent("Total", value: byteString(stats.bytesCleaned))
        .fontWeight(.semibold)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
  }

  private var footer: some View {
    VStack(spacing: 6) {
      Text(
        "Includes photos still in Recently Deleted.\nTheir space is freed after 30 days."
      )
      if let since = stats.trackingSince {
        Text("Tracking since \(since.formatted(date: .abbreviated, time: .omitted))")
      }
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
    .padding(.horizontal, 16)
  }

  private var clearButton: some View {
    Button("Clear lifetime stats", role: .destructive) {
      showClearConfirmation = true
    }
    .disabled(stats.trackingSince == nil)
    .padding(.top, 8)
    .alert("Clear lifetime stats?", isPresented: $showClearConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Clear", role: .destructive, action: onClear)
    } message: {
      Text("Totals and the tracking date start over. Your photos aren't changed.")
    }
  }

  private static let ratioBarSpacing: CGFloat = 3

  private func byteString(_ bytes: Int64) -> String {
    bytes.formatted(.byteCount(style: .file))
  }
}

#Preview {
  NavigationStack {
    LifetimeStatsView(
      stats: LifetimeSessionStats(
        totalReviewed: 1_480,
        totalKept: 1_206,
        totalDeleted: 274,
        bytesDeleted: 1_840_000_000,
        livePhotosConverted: 62,
        bytesSavedByConversion: 310_000_000,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)
      ),
      reviewedPhotoCount: 1_206,
      libraryPhotoCount: 3_100,
      onClear: {}
    )
  }
}
