// CoreMems/Views/Screens/SettingsView.swift
import SwiftUI

/// Lifetime stats summary and review preferences. Pushed from Setup.
struct SettingsView: View {
  @Binding var checkInInterval: Int
  @Binding var includesReviewedPhotos: Bool
  let reviewedPhotoCount: Int
  let libraryPhotoCount: Int
  let onResetReviewedPhotos: () -> Void
  let pinnedAlbums: PinnedAlbumsViewModel
  /// The pinned album IDs in display order.
  let pinnedAlbumOrder: [String]
  let lifetimeStats: LifetimeSessionStats
  let onClearLifetimeStats: () -> Void

  @State private var showResetConfirmation = false

  private var checkInRange: ClosedRange<Double> {
    let bounds = SessionSettings.checkInIntervalRange
    return Double(bounds.lowerBound)...Double(bounds.upperBound)
  }

  var body: some View {
    Form {
      statsSection
      pinnedAlbumsSection
      checkInSection
      reviewedPhotosSection
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Reset review history?", isPresented: $showResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive, action: onResetReviewedPhotos)
    } message: {
      Text("Every photo becomes eligible for review again. Your photos aren't changed.")
    }
  }

  private var checkInSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Stepper(
          "Every \(checkInInterval) photos", value: $checkInInterval,
          in: SessionSettings.checkInIntervalRange)
        Slider(
          value: Binding(
            get: { Double(checkInInterval) },
            set: { checkInInterval = Int($0.rounded()) }
          ),
          in: checkInRange,
          step: 1
        )
        HStack {
          Text("\(SessionSettings.checkInIntervalRange.lowerBound)")
          Spacer()
          Text("\(SessionSettings.checkInIntervalRange.upperBound)")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
      }
    } header: {
      Text("Check-in frequency")
    } footer: {
      Text(
        "Every session keeps going until you stop. Pick how often you'd like a quick \"keep going?\" check-in along the way."
      )
    }
  }

  private var reviewedPhotosSection: some View {
    Section {
      Toggle("Include reviewed photos", isOn: $includesReviewedPhotos)
      LabeledContent("Reviewed so far", value: reviewedPhotoCount.formatted())
      Button("Reset review history", role: .destructive) {
        showResetConfirmation = true
      }
      .disabled(reviewedPhotoCount == 0)
    } header: {
      Text("Reviewed photos")
    } footer: {
      Text(
        "Photos you've kept in earlier sessions are skipped, so each session picks up where the last one left off."
      )
    }
  }

  private var pinnedAlbumsSection: some View {
    Section {
      NavigationLink {
        PinnedAlbumsSettingsView(pinnedAlbums: pinnedAlbums, pinnedIdentifiers: pinnedAlbumOrder)
          .task { pinnedAlbums.load() }
      } label: {
        Label("Choose albums", systemImage: "pin.fill")
      }
    } header: {
      Text("Pinned albums")
    }
  }

  private var statsSection: some View {
    Section {
      NavigationLink {
        LifetimeStatsView(
          stats: lifetimeStats, reviewedPhotoCount: reviewedPhotoCount,
          libraryPhotoCount: libraryPhotoCount, onClear: onClearLifetimeStats)
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(lifetimeStats.totalDeleted.formatted())
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .monospacedDigit()
          Text("photos deleted")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
      }
    } header: {
      Text("Lifetime stats")
    } footer: {
      if lifetimeStats.sessionsCompleted == 0 {
        Text("Stats appear after you complete your first session.")
      }
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView(
      checkInInterval: .constant(12),
      includesReviewedPhotos: .constant(false),
      reviewedPhotoCount: 128,
      libraryPhotoCount: 3_100,
      onResetReviewedPhotos: {},
      pinnedAlbums: .mock(),
      pinnedAlbumOrder: [],
      lifetimeStats: LifetimeSessionStats(
        totalReviewed: 150,
        totalKept: 100,
        totalDeleted: 50,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)
      ),
      onClearLifetimeStats: {}
    )
  }
}
