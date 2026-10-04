// CoreMems/Views/Screens/SettingsView.swift
import SwiftUI

/// Lifetime stats summary and review preferences. Pushed from Home.
struct SettingsView: View {
  @Binding var checkInInterval: Int
  @Binding var includesKeptPhotos: Bool
  @Binding var tracksKeptHistory: Bool
  @Binding var networkPolicy: NetworkPolicy
  let isLowDataModeActive: Bool
  let keptPhotoCount: Int
  let libraryPhotoCount: Int
  let onResetKeptPhotos: () -> Void
  let pinnedAlbums: PinnedAlbumsViewModel
  /// Recently used album IDs, newest first; orders pinned albums when sorted by recency.
  let recentAlbumIDs: [String]
  let lifetimeStats: LifetimeSessionStats
  let onClearLifetimeStats: () -> Void

  @State private var showResetConfirmation = false
  @State private var appDataBytes: Int64 = 0

  private var checkInRange: ClosedRange<Double> {
    let bounds = SessionSettings.checkInIntervalRange
    return Double(bounds.lowerBound)...Double(bounds.upperBound)
  }

  var body: some View {
    Form {
      statsSection
      pinnedAlbumsSection
      checkInSection
      keptPhotosSection
      dataUsageSection
      #if DEBUG
        debugSection
      #endif
      appDataSection
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Reset kept history?", isPresented: $showResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive, action: onResetKeptPhotos)
    } message: {
      Text("Every kept photo becomes eligible to appear again. Your photos aren't changed.")
    }
    .task {
      appDataBytes = await Task.detached { LocalStorageSize.totalBytes() }.value
    }
  }

  private var appDataSection: some View {
    Section {
      LabeledContent("Local storage", value: appDataBytes.fileSizeText)
    } footer: {
      Text("Doesn't include your photos.")
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

  #if DEBUG
    private var debugSection: some View {
      Section {
        NavigationLink("Debug") {
          DebugSettingsView()
        }
      }
    }
  #endif

  private var keptPhotosSection: some View {
    Section {
      Toggle("Track kept history", isOn: $tracksKeptHistory)
      Toggle("Include kept photos", isOn: $includesKeptPhotos)
      LabeledContent("Kept so far", value: keptPhotoCount.formatted())
      Button("Reset kept history", role: .destructive) {
        showResetConfirmation = true
      }
      .disabled(keptPhotoCount == 0)
    } header: {
      Text("Kept photos")
    } footer: {
      Text(
        "Photos you've kept in earlier sessions are skipped, so each session picks up where the last one left off. Turning off tracking stops remembering new ones."
      )
    }
  }

  private var dataUsageSection: some View {
    Section {
      if isLowDataModeActive {
        Label(NetworkPauseReason.lowDataMode, systemImage: "bolt.slash")
          .foregroundStyle(.secondary)
      }
      Picker("iCloud downloads", selection: $networkPolicy) {
        ForEach(NetworkPolicy.allCases, id: \.self) { policy in
          Text(policy.label).tag(policy)
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
    } header: {
      Text("Data usage")
    } footer: {
      Text(
        isLowDataModeActive
          ? "Downloads stay paused no matter what's picked above. Turn it off in the network's Wi-Fi or Cellular settings to allow downloads again."
          : "Photos stored only in iCloud need a download for full quality. Without one, the session shows what's already cached and skips a photo only if nothing is. Offline and Low Data Mode always skip downloads."
      )
    }
  }

  private var pinnedAlbumsSection: some View {
    Section {
      NavigationLink {
        PinnedAlbumsSettingsView(pinnedAlbums: pinnedAlbums, recentAlbumIDs: recentAlbumIDs)
          .task { pinnedAlbums.load() }
      } label: {
        Label("Choose albums", systemImage: "pin.fill")
      }
    } header: {
      Text("Pinned albums")
    } footer: {
      Text("Pinned albums show first when you add a photo to an album.")
    }
  }

  private var statsSection: some View {
    Section {
      NavigationLink {
        LifetimeStatsView(
          stats: lifetimeStats, keptPhotoCount: keptPhotoCount,
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

/// Settings display text for each network policy.
extension NetworkPolicy {
  fileprivate var label: String {
    switch self {
    case .wifiAndCellular: return "Wi-Fi and cellular"
    case .wifiOnly: return "Wi-Fi only"
    case .downloadedOnly: return "Downloaded photos only"
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView(
      checkInInterval: .constant(12),
      includesKeptPhotos: .constant(false),
      tracksKeptHistory: .constant(true),
      networkPolicy: .constant(.wifiAndCellular),
      isLowDataModeActive: false,
      keptPhotoCount: 128,
      libraryPhotoCount: 3_100,
      onResetKeptPhotos: {},
      pinnedAlbums: .mock(),
      recentAlbumIDs: [],
      lifetimeStats: LifetimeSessionStats(
        totalKept: 100,
        totalDeleted: 50,
        sessionsCompleted: 12,
        trackingSince: Date(timeIntervalSince1970: 1_640_995_200)
      ),
      onClearLifetimeStats: {}
    )
  }
}
