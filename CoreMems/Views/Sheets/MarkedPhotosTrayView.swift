// CoreMems/Views/Sheets/MarkedPhotosTrayView.swift
import SwiftUI

/// Everything that changes when the session is confirmed, in review order.
struct MarkedPhotosTrayView: View {
  let items: [SessionPhoto]
  let onRestore: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if items.isEmpty {
          VStack(spacing: 10) {
            Image(systemName: "tray")
              .font(.largeTitle)
              .foregroundStyle(.tertiary)
            Text(
              "Nothing marked yet. Swipe down on a photo to mark it for deletion, or convert a Live Photo to a still."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          PhotoGrid(photos: items, showsDecisionTags: true, onRestore: onRestore)
        }
      }
      .navigationTitle("Marked photos")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}
