import SwiftUI

struct PendingReviewView: View {
  @ObservedObject var vm: SessionViewModel
  @Binding var showConfirm: Bool

  @State private var selected: Set<String> = []

  private var items: [SessionPhoto] { vm.pendingItems }
  private var hasItems: Bool { !items.isEmpty }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "Before you go", onBack: { vm.screen = .review })

      VStack(alignment: .leading, spacing: 8) {
        Text(
          hasItems
            ? "\(items.count) photo\(items.count == 1 ? "" : "s") will move to Recently Deleted"
            : "Nothing marked for deletion"
        )
        .font(.title3.bold())

        Text(
          hasItems
            ? "Nothing is deleted yet. They'll sit in Recently Deleted for Apple's usual 30 days, so you can still change your mind after this."
            : "You kept all \(vm.keptCount) photos from this session. Nothing will be deleted."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 26)
      .padding(.top, 4)

      PhotoGrid(photos: items) { id in
        vm.restoreMany(ids: [id])
      }

      Spacer(minLength: 0)

      if let albumAssignmentError = vm.albumAssignmentError {
        VStack(spacing: 8) {
          Text(albumAssignmentError)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
          Button("Retry saving to albums") {
            vm.retryAlbumAssignments()
          }
          .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 26)
      }

      Button {
        if hasItems {
          showConfirm = true
        } else {
          Task { await vm.confirmDeletion() }
        }
      } label: {
        if vm.isFlushingAlbums {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else {
          Text(
            hasItems
              ? "Delete \(items.count) photo\(items.count == 1 ? "" : "s")" : "Finish session"
          )
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(hasItems ? .red : .blue)
      .disabled(vm.isFlushingAlbums)
      .padding(26)
    }
  }
}
