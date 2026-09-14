import SwiftUI

// MARK: - Pending Review

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

      Button {
        if hasItems {
          showConfirm = true
        } else {
          Task { await vm.confirmDeletion() }
        }
      } label: {
        Text(
          hasItems ? "Delete \(items.count) photo\(items.count == 1 ? "" : "s")" : "Finish session"
        )
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
      }
      .buttonStyle(.borderedProminent)
      .tint(hasItems ? .red : .blue)
      .padding(26)
    }
  }
}

// MARK: - Confirm Sheet

struct ConfirmSheetView: View {
  let count: Int
  let favoritesCount: Int
  let isDeleting: Bool
  let errorMessage: String?
  let onCancel: () -> Void
  let onConfirm: () -> Void

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
