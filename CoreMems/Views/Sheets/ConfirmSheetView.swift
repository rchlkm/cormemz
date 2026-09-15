import SwiftUI

struct ConfirmSheetView: View {
  let count: Int
  let favoritesCount: Int
  let isDeleting: Bool
  let errorMessage: String?
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

      if let errorMessage {
        Text(errorMessage)
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
            .font(.footnote.weight(.semibold))
            .disabled(isDeleting)
        }
      }

      GeometryReader { geo in
        HStack(spacing: 10) {
          Button("Cancel", action: onCancel)
            .buttonStyle(SecondaryActionButtonStyle())
            .frame(height: 56)
            .disabled(isDeleting)

          Button(action: onConfirm) {
            if isDeleting {
              ProgressView()
            } else {
              Text("Confirm")
            }
          }
          .buttonStyle(DestructiveActionButtonStyle())
          .frame(minWidth: 140, maxWidth: .infinity)
          .frame(height: 56)
          .disabled(isDeleting)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(24)
  }
}
