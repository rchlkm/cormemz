// CoreMems/Views/Sheets/ConfirmSheetView.swift
import SwiftUI

struct ConfirmSheetView: View {
  let count: Int
  let favoritesCount: Int
  let conversionCount: Int
  let isDeleting: Bool
  let errorMessage: String?
  let conversionErrorMessage: String?
  let albumErrorMessage: String?
  let onCancel: () -> Void
  let onConfirm: () -> Void
  let onRetryAlbums: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Text("Move \(count) photo\(count == 1 ? "" : "s") to Recently Deleted?")
        .font(.title3.bold())
        .multilineTextAlignment(.center)

      Text(
        "They won't be removed from your phone right away — Photos keeps them in Recently Deleted for about 30 days before they're gone for good."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)

      if favoritesCount > 0 {
        Label(
          "\(favoritesCount) \(favoritesCount == 1 ? "is" : "are") marked as a favorite",
          systemImage: "heart.fill"
        )
        .font(.footnote)
        .foregroundStyle(.pink)
      }

      if conversionCount > 0 {
        Label(
          "\(conversionCount) Live Photo\(conversionCount == 1 ? "" : "s") will also be converted to a still, with the original moved to Recently Deleted",
          systemImage: "livephoto"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
      }

      if let conversionErrorMessage {
        Text(conversionErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
      }

      if let albumErrorMessage {
        VStack(spacing: 6) {
          Text(albumErrorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
          Button("Retry saving to albums", action: onRetryAlbums)
            .buttonStyle(InlineButtonStyle(tint: .accentColor))
            .disabled(isDeleting)
        }
      }

      GeometryReader { geo in
        HStack(spacing: 10) {
          Button("Cancel", action: onCancel)
            .buttonStyle(ActionButtonStyle(role: .secondary))
            .disabled(isDeleting)

          Button(action: onConfirm) {
            if isDeleting {
              ProgressView()
            } else {
              Text("Confirm")
            }
          }
          .buttonStyle(ActionButtonStyle(role: .destructive))
          .frame(minWidth: 140, maxWidth: .infinity)
          .disabled(isDeleting)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(24)
  }
}
