// CoreMems/Views/Sheets/ReviewedPhotosSettingsView.swift
import SwiftUI

struct ReviewedPhotosSettingsView: View {
  @Binding var includesReviewed: Bool
  let reviewedCount: Int
  let onReset: () -> Void

  @State private var showResetConfirmation = false

  var body: some View {
    VStack(spacing: 20) {
      Text("Reviewed photos")
        .font(.headline)
        .padding(.top, 20)

      Text(
        "Photos you've kept in earlier sessions are skipped, so each session picks up where the last one left off."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 24)

      Toggle("Include reviewed photos", isOn: $includesReviewed)
        .padding(.horizontal, 24)

      VStack(spacing: 8) {
        Text("\(reviewedCount) reviewed photo\(reviewedCount == 1 ? "" : "s")")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Reset review history", role: .destructive) {
          showResetConfirmation = true
        }
        .disabled(reviewedCount == 0)
      }

      Spacer(minLength: 12)
    }
    .presentationDetents([.height(340)])
    .confirmationDialog(
      "Reset review history?", isPresented: $showResetConfirmation, titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive, action: onReset)
    } message: {
      Text("Every photo becomes eligible for review again. Your photos aren't changed.")
    }
  }
}

#Preview {
  ReviewedPhotosSettingsView(
    includesReviewed: .constant(false), reviewedCount: 128, onReset: {})
}
