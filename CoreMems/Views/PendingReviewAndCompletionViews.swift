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

      ScrollView {
        if hasItems {
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10
          ) {
            ForEach(items) { photo in
              ZStack(alignment: .topTrailing) {
                AdaptiveAssetImage(photo: photo, targetSize: CGSize(width: 200, height: 200))
                  .aspectRatio(1, contentMode: .fill)
                  .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                  vm.restoreMany(ids: [photo.id])
                } label: {
                  Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(6)
                    .background(.white.opacity(0.9), in: Circle())
                }
                .padding(6)
              }
            }
          }
          .padding(.horizontal, 26)
          .padding(.top, 16)
        }
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

      HStack(spacing: 10) {
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
          .frame(maxWidth: .infinity)

        Button(action: onConfirm) {
          if isDeleting {
            ProgressView().frame(maxWidth: .infinity)
          } else {
            Text("Confirm").frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isDeleting)
      }
    }
    .padding(24)
  }
}

// MARK: - Completion

struct CompletionScreen_Preview: PreviewProvider {
  static var previews: some View {
    CompletionView(keptCount: 7, deletedCount: 3, onHome: {}, onAgain: {})
  }
}

struct CompletionView: View {
  let keptCount: Int
  let deletedCount: Int
  let onHome: () -> Void
  let onAgain: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(.green)

      Text("Session complete")
        .font(.title2.bold())

      Text(
        "You kept \(keptCount) photo\(keptCount == 1 ? "" : "s")"
          + (deletedCount > 0 ? " and moved \(deletedCount) to Recently Deleted." : ".")
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)

      if deletedCount > 0 {
        Text("They're recoverable from the Photos app if you change your mind.")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      Spacer()

      HStack(spacing: 10) {
        Button("Home", action: onHome)
          .buttonStyle(.bordered)
          .frame(maxWidth: .infinity)

        Button("Another session", action: onAgain)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, 32)
      .padding(.bottom, 26)
    }
  }
}
