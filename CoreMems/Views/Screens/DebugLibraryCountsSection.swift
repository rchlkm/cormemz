// CoreMems/Views/Screens/DebugLibraryCountsSection.swift
#if DEBUG
  import SwiftUI

  /// Settings readout of PhotoKit asset counts under different fetch options.
  struct DebugLibraryCountsSection: View {
    @State private var report: String?
    @State private var isCounting = false
    @State private var didCopy = false

    var body: some View {
      Section {
        Button(action: count) {
          HStack {
            Text("Count library assets")
            if isCounting {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(isCounting)
        if let report {
          Button(action: { copy(report) }) {
            Text(report)
              .font(.caption.monospaced())
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text("Debug library counts")
      } footer: {
        Text(footerText)
      }
    }

    private var footerText: String {
      didCopy
        ? "Copied to the clipboard."
        : "Compares what PhotoKit returns under different fetch options with the Photos app's totals. Tap the report to copy it."
    }

    private func count() {
      isCounting = true
      didCopy = false
      Task {
        let report = await Task.detached { LibraryCountDiagnostics.makeReport() }.value
        print("[CoreMems] library counts\n\(report)")
        self.report = report
        isCounting = false
      }
    }

    private func copy(_ report: String) {
      UIPasteboard.general.string = report
      didCopy = true
    }
  }
#endif
