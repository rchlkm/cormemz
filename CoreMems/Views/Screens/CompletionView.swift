// CoreMems/Views/Screens/CompletionView.swift
import SwiftUI

struct CompletionView: View {
  let keptCount: Int
  let deletedCount: Int
  let albumAssignedCount: Int
  /// Staged album adds/removes that no-op'd because the album no longer existed.
  let missingAlbumCount: Int
  let convertedCount: Int
  let editedCount: Int
  let deletedBytes: Int64
  let convertedBytesSaved: Int64
  let decidedPhotoCount: Int
  let libraryPhotoCount: Int
  let onAgain: () -> Void

  /// Converted and edited photos are also counted in `keptCount`; they get their own tiles.
  private var keptUnchangedCount: Int { max(keptCount - convertedCount - editedCount, 0) }

  private var tiles: [StatTileItem] {
    var items = [
      StatTileItem(
        label: "Kept", value: keptUnchangedCount.formatted(),
        systemImage: "checkmark", tint: Decision.keep.tint),
      StatTileItem(
        label: "Deleted", value: deletedCount.formatted(), systemImage: "trash",
        tint: Decision.pendingDelete.tint),
    ]
    if convertedCount > 0 {
      items.append(
        StatTileItem(
          label: "Converted to stills", value: convertedCount.formatted(),
          systemImage: "livephoto", tint: Decision.convertToStill.tint))
    }
    if editedCount > 0 {
      items.append(
        StatTileItem(
          label: "Edited", value: editedCount.formatted(),
          systemImage: DecisionOverlay.content(for: .edited).icon, tint: Decision.edited.tint))
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
          if missingAlbumCount > 0 {
            Text(
              "\(missingAlbumCount) album assignment\(missingAlbumCount == 1 ? "" : "s") "
                + "couldn't be made — the album may have been deleted."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
          }
          OutcomeRatioCard(
            kept: keptUnchangedCount, converted: convertedCount, edited: editedCount,
            deleted: deletedCount)
          if deletedBytes + convertedBytesSaved > 0 {
            SpaceCleanedCard(deletedBytes: deletedBytes, convertedBytes: convertedBytesSaved)
          }
          BrowseProgressCard(decided: decidedPhotoCount, total: libraryPhotoCount)
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
        .foregroundStyle(Decision.keep.tint)
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
    missingAlbumCount: 1,
    convertedCount: 1,
    editedCount: 2,
    deletedBytes: 1_840_000_000,
    convertedBytesSaved: 310_000_000,
    decidedPhotoCount: 1_206,
    libraryPhotoCount: 3_100,
    onAgain: {})
}
