// CoreMems/Views/Screens/CompletionView.swift
import SwiftUI

struct CompletionView: View {
  let keptCount: Int
  let deletedCount: Int
  let albumAssignedCount: Int
  let convertedCount: Int
  let deletedBytes: Int64
  let convertedBytesSaved: Int64
  let reviewedPhotoCount: Int
  let libraryPhotoCount: Int
  let onAgain: () -> Void

  /// Converted photos are also counted in `keptCount`; they get their own tile.
  private var keptUnchangedCount: Int { max(keptCount - convertedCount, 0) }

  private var tiles: [StatTileItem] {
    var items = [
      StatTileItem(
        label: "Kept", value: keptUnchangedCount.formatted(),
        systemImage: "checkmark", tint: ReviewDecision.keep.tint),
      StatTileItem(
        label: "Deleted", value: deletedCount.formatted(), systemImage: "trash",
        tint: ReviewDecision.pendingDelete.tint),
    ]
    if convertedCount > 0 {
      items.append(
        StatTileItem(
          label: "Converted to stills", value: convertedCount.formatted(),
          systemImage: "livephoto", tint: ReviewDecision.convertToStill.tint))
    }
    if albumAssignedCount > 0 {
      items.append(
        StatTileItem(
          label: "Added to albums", value: albumAssignedCount.formatted(),
          systemImage: "rectangle.stack"))
    }
    return items
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 20) {
          header
          StatTileGrid(items: tiles)
          if deletedCount > 0 {
            Text("Deleted photos stay in Recently Deleted for 30 days.")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          OutcomeRatioCard(
            kept: keptUnchangedCount, converted: convertedCount, deleted: deletedCount)
          if deletedBytes + convertedBytesSaved > 0 {
            SpaceCleanedCard(deletedBytes: deletedBytes, convertedBytes: convertedBytesSaved)
          }
          ReviewProgressCard(reviewed: reviewedPhotoCount, total: libraryPhotoCount)
        }
        .padding(.horizontal, 16)
        .padding(.top, 48)
        .padding(.bottom, 20)
      }

      Button("Another session", action: onAgain)
        .buttonStyle(ActionButtonStyle(role: .primary))
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
    }
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
  }

  private var header: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(ReviewDecision.keep.tint)
      Text("Session complete")
        .font(.title2.bold())
    }
  }
}

#Preview {
  CompletionView(
    keptCount: 8,
    deletedCount: 3,
    albumAssignedCount: 2,
    convertedCount: 1,
    deletedBytes: 1_840_000_000,
    convertedBytesSaved: 310_000_000,
    reviewedPhotoCount: 1_206,
    libraryPhotoCount: 3_100,
    onAgain: {})
}
