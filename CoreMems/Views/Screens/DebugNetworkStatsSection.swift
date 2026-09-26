// CoreMems/Views/Screens/DebugNetworkStatsSection.swift
#if DEBUG
  import SwiftUI

  /// Settings readout of photos downloaded from iCloud this launch.
  struct DebugNetworkStatsSection: View {
    @ObservedObject private var stats = NetworkDownloadStats.shared

    var body: some View {
      Section {
        LabeledContent("Downloads", value: stats.downloadCount.formatted())
        LabeledContent("Up to", value: stats.estimatedBytes.fileSizeText)
        Button("Reset counters", role: .destructive) { stats.reset() }
      } header: {
        Text("Debug network")
      } footer: {
        Text("Photos fetched from iCloud since launch. Sizes are the originals', so they are an upper bound.")
      }
    }
  }
#endif
