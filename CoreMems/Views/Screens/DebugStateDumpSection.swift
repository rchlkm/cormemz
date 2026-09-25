// CoreMems/Views/Screens/DebugStateDumpSection.swift
#if DEBUG
  import SwiftUI

  /// Settings controls for the persisted-state dump.
  struct DebugStateDumpSection: View {
    @AppStorage(PersistedStateDump.enabledKey) private var isEnabled = false
    @State private var hasDump = PersistedStateDump.reportExists

    var body: some View {
      Section {
        Toggle("Dump persisted state", isOn: $isEnabled)
        Button("Dump now") {
          PersistedStateDump.run(reason: "manual")
          hasDump = PersistedStateDump.reportExists
        }
        if hasDump {
          ShareLink("Share dump file", item: PersistedStateDump.reportURL)
          Button("Delete dump file", role: .destructive) {
            PersistedStateDump.deleteReport()
            hasDump = PersistedStateDump.reportExists
          }
        }
      } header: {
        Text("Debug")
      } footer: {
        Text("When on, dumps at launch and when backgrounded. Share sends the file via AirDrop or Save to Files.")
      }
    }
  }
#endif
