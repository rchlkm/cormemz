// CoreMems/Views/Screens/DebugSettingsView.swift
#if DEBUG
  import SwiftUI

  /// Debug-only diagnostics, pushed from Settings.
  struct DebugSettingsView: View {
    var body: some View {
      Form {
        DebugStateDumpSection()
        DebugNetworkStatsSection()
        DebugLibraryCountsSection()
        DebugEditFailuresSection()
      }
      .navigationTitle("Debug")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  #Preview {
    NavigationStack {
      DebugSettingsView()
    }
  }
#endif
