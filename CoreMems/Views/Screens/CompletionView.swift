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
  /// Edits that couldn't be saved, offered for a retry.
  let failedEdits: [FailedEdit]
  /// Returns the edits still failing.
  let onRetryEdits: ([String]) async -> [String: EditFailureReason]
  let onDiscardEdit: (String) -> Void
  let deletedBytes: Int64
  let convertedBytesSaved: Int64
  let trimmedBytesSaved: Int64
  let keptPhotoCount: Int
  let libraryPhotoCount: Int
  let onAgain: () -> Void

  /// Converted photos are also counted in `keptCount`; they get their own tile.
  private var keptUnchangedCount: Int { max(keptCount - convertedCount, 0) }

  /// Tiles for the outcomes that happened; the kept tile alone when none did.
  var tiles: [StatTileItem] {
    func tile(_ label: String, _ count: Int, _ systemImage: String, _ tint: Color? = nil)
      -> (count: Int, item: StatTileItem)
    {
      (count, StatTileItem(label: label, value: count.formatted(), systemImage: systemImage, tint: tint))
    }
    let outcomes = [
      tile("Kept", keptUnchangedCount, "checkmark", Decision.keep.tint),
      tile("Deleted", deletedCount, "trash", Decision.pendingDelete.tint),
      tile("Converted to stills", convertedCount, "livephoto", Decision.convertToStill.tint),
      tile("Edited", editedCount, EditStyle.symbol, EditStyle.tint),
      tile("Added to albums", albumAssignedCount, "rectangle.stack"),
    ]
    let happened = outcomes.filter { $0.count > 0 }.map(\.item)
    return happened.isEmpty ? [outcomes[0].item] : happened
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 20) {
          header
          OutcomeRatioCard(
            kept: keptUnchangedCount, converted: convertedCount, deleted: deletedCount)
          StatTileGrid(items: tiles)
          if deletedCount > 0 {
            Text("Deleted photos stay in Recently Deleted for 30 days.")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          if !failedEdits.isEmpty {
            FailedEditsCard(failures: failedEdits, onRetry: onRetryEdits, onDiscard: onDiscardEdit)
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
          if deletedBytes + convertedBytesSaved + trimmedBytesSaved > 0 {
            SpaceCleanedCard(
              deletedBytes: deletedBytes, convertedBytes: convertedBytesSaved,
              trimmedBytes: trimmedBytesSaved)
          }
          BrowseProgressCard(kept: keptPhotoCount, total: libraryPhotoCount)
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
    failedEdits: [],
    onRetryEdits: { _ in [:] },
    onDiscardEdit: { _ in },
    deletedBytes: 1_840_000_000,
    convertedBytesSaved: 310_000_000,
    trimmedBytesSaved: 95_000_000,
    keptPhotoCount: 1_206,
    libraryPhotoCount: 3_100,
    onAgain: {})
}
