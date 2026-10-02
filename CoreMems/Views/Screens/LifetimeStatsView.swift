// CoreMems/Views/Screens/LifetimeStatsView.swift
import SwiftUI

/// Every lifetime stat in one place. Pushed from the top of Settings.
struct LifetimeStatsView: View {
  let stats: LifetimeSessionStats
  let decidedPhotoCount: Int
  let libraryPhotoCount: Int
  let onClear: () -> Void

  @State private var showClearConfirmation = false

  private var tiles: [StatTileItem] {
    [
      StatTileItem(
        label: "Sessions", value: stats.sessionsCompleted.formatted(),
        systemImage: "clock.arrow.circlepath"),
      StatTileItem(
        label: "Kept", value: stats.keptUnchanged.formatted(), systemImage: "checkmark.circle",
        tint: Decision.keep.tint),
      StatTileItem(label: "Decided", value: stats.totalDecided.formatted(), systemImage: "eye"),
      StatTileItem(
        label: "Live Photos converted", value: stats.livePhotosConverted.formatted(),
        systemImage: "livephoto", tint: Decision.convertToStill.tint),
      StatTileItem(
        label: "Edited", value: stats.mediaEdited.formatted(),
        systemImage: EditStyle.symbol, tint: EditStyle.tint),
    ]
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        hero
        StatTileGrid(items: tiles)
        OutcomeRatioCard(
          kept: stats.keptUnchanged, converted: stats.livePhotosConverted,
          deleted: stats.totalDeleted)
        BrowseProgressCard(decided: decidedPhotoCount, total: libraryPhotoCount)
        SpaceCleanedCard(
          deletedBytes: stats.bytesDeleted, convertedBytes: stats.bytesSavedByConversion)
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
      Text("\(stats.bytesCleaned.fileSizeText) cleaned")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .cardBackground()
    .accessibilityElement(children: .combine)
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
}

#Preview {
  NavigationStack {
    LifetimeStatsView(
      stats: LifetimeSessionStats(
        totalDecided: 1_480,
        totalKept: 1_206,
        totalDeleted: 274,
        bytesDeleted: 1_840_000_000,
        livePhotosConverted: 62,
        bytesSavedByConversion: 310_000_000,
        mediaEdited: 18,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)
      ),
      decidedPhotoCount: 1_206,
      libraryPhotoCount: 3_100,
      onClear: {}
    )
  }
}
