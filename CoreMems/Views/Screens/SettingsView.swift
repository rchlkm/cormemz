// CoreMems/Views/Screens/SettingsView.swift
import SwiftUI

/// Review preferences and lifetime app stats. Pushed from Setup.
struct SettingsView: View {
  @Binding var checkInInterval: Int
  @Binding var includesReviewedPhotos: Bool
  let reviewedPhotoCount: Int
  let onResetReviewedPhotos: () -> Void
  let pinnedAlbums: [AlbumOption]
  let pinnedAlbumIdentifiers: Set<String>
  let isLoadingPinnedAlbums: Bool
  var isCreatingPinnedAlbum: Bool = false
  var pinnedAlbumCreationError: String? = nil
  let onLoadPinnedAlbums: () -> Void
  let onTogglePinnedAlbum: (String) -> Void
  let onCreateAndPinAlbum: (String) -> Void
  let lifetimeStats: LifetimeSessionStats

  @State private var showResetConfirmation = false

  private struct StatRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
  }

  private var checkInRange: ClosedRange<Double> {
    let bounds = SessionViewModel.checkInIntervalRange
    return Double(bounds.lowerBound)...Double(bounds.upperBound)
  }

  private var statRows: [StatRow] {
    var rows = [
      StatRow(label: "Photos reviewed", value: lifetimeStats.totalReviewed.formatted()),
      StatRow(label: "Kept", value: lifetimeStats.totalKept.formatted()),
      StatRow(
        label: "Moved to Recently Deleted", value: lifetimeStats.totalDeleted.formatted()),
      StatRow(label: "Sessions completed", value: lifetimeStats.sessionsCompleted.formatted()),
    ]
    if let since = lifetimeStats.trackingSince {
      rows.append(
        StatRow(
          label: "Tracking since", value: since.formatted(date: .abbreviated, time: .omitted)))
    }
    return rows
  }

  var body: some View {
    Form {
      pinnedAlbumsSection
      checkInSection
      reviewedPhotosSection
      statsSection
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Reset review history?", isPresented: $showResetConfirmation, titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive, action: onResetReviewedPhotos)
    } message: {
      Text("Every photo becomes eligible for review again. Your photos aren't changed.")
    }
  }

  private var checkInSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text("Every \(checkInInterval) photos")
        Slider(
          value: Binding(
            get: { Double(checkInInterval) },
            set: { checkInInterval = Int($0.rounded()) }
          ),
          in: checkInRange,
          step: 1
        )
        HStack {
          Text("\(SessionViewModel.checkInIntervalRange.lowerBound)")
          Spacer()
          Text("\(SessionViewModel.checkInIntervalRange.upperBound)")
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
        PinnedAlbumsSettingsView(
          albums: pinnedAlbums,
          pinnedIdentifiers: pinnedAlbumIdentifiers,
          isLoading: isLoadingPinnedAlbums,
          isCreating: isCreatingPinnedAlbum,
          creationError: pinnedAlbumCreationError,
          onTogglePin: onTogglePinnedAlbum,
          onCreateAndPin: onCreateAndPinAlbum
        )
        .task { onLoadPinnedAlbums() }
      } label: {
        Label("Choose albums", systemImage: "pin.fill")
      }
    } header: {
      Text("Pinned albums")
    }
  }

  private var statsSection: some View {
    Section {
      ForEach(statRows) { LabeledContent($0.label, value: $0.value) }
    } header: {
      Text("Stats")
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
      onResetReviewedPhotos: {},
      pinnedAlbums: [],
      pinnedAlbumIdentifiers: [],
      isLoadingPinnedAlbums: false,
      onLoadPinnedAlbums: {},
      onTogglePinnedAlbum: { _ in },
      onCreateAndPinAlbum: { _ in },
      lifetimeStats: LifetimeSessionStats(
        totalReviewed: 150,
        totalKept: 100,
        totalDeleted: 50,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)
      )
    )
  }
}
