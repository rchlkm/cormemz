// CoreMems/Views/Screens/DebugEditFailuresSection.swift
#if DEBUG
  import SwiftUI

  /// Settings control for making edits fail on Apply.
  struct DebugEditFailuresSection: View {
    @AppStorage(EditFailureSimulation.key) private var mode = EditFailureSimulation.Mode.off

    var body: some View {
      Section {
        Picker("Fail edits", selection: $mode) {
          ForEach(EditFailureSimulation.Mode.allCases) { Text($0.title).tag($0) }
        }
      } header: {
        Text("Debug editing")
      } footer: {
        Text("\"First try\" fails each edit once, so Try again succeeds. \"Every try\" keeps failing.")
      }
    }
  }
#endif
