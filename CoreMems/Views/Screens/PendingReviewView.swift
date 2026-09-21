// CoreMems/Views/Screens/PendingReviewView.swift
import SwiftUI

struct PendingReviewView: View {
  @ObservedObject var vm: SessionViewModel
  @Binding var showConfirm: Bool

  @State private var selected: Set<String> = []

  private var items: [SessionPhoto] { vm.pendingItems }
  private var conversions: [SessionPhoto] { vm.pendingConversions }
  private var hasItems: Bool { !items.isEmpty }
  private var isBusy: Bool { vm.isFlushingAlbums || vm.isConvertingLivePhoto || vm.isDeleting }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "Before you go", onBack: { vm.screen = .review })

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if items.isEmpty && conversions.isEmpty {
            header(
              title: "Nothing marked for deletion",
              subtitle: "You kept all \(vm.keptCount) photos from this session. Nothing will be deleted."
            )
          }
          if hasItems {
            section(
              title: "\(items.count) photo\(items.count == 1 ? "" : "s") will move to Recently Deleted",
              subtitle:
                "Nothing is deleted yet. They'll sit in Recently Deleted for Apple's usual 30 days, so you can still change your mind after this.",
              photos: items)
          }
          if !conversions.isEmpty {
            section(
              title: conversions.count == 1
                ? "1 Live Photo will become a still photo"
                : "\(conversions.count) Live Photos will become still photos",
              subtitle:
                "Each keeps its still image, and the Live Photo original moves to Recently Deleted.",
              photos: conversions)
          }
        }
        .padding(.top, 4)
      }

      if let albumAssignmentError = vm.albumAssignmentError {
        VStack(spacing: 8) {
          Text(albumAssignmentError)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
          Button("Retry saving to albums") {
            vm.retryAlbumAssignments()
          }
          .buttonStyle(InlineButtonStyle(tint: .accentColor))
        }
        .padding(.horizontal, 26)
      }

      if let conversionError = vm.livePhotoConversionError {
        Text(conversionError)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 26)
      }

      Button {
        if hasItems {
          showConfirm = true
        } else {
          Task { await vm.confirmDeletion() }
        }
      } label: {
        if isBusy {
          ProgressView()
        } else {
          Text(
            hasItems
              ? "Delete \(items.count) photo\(items.count == 1 ? "" : "s")" : "Finish session"
          )
        }
      }
      .buttonStyle(ActionButtonStyle(role: hasItems ? .destructive : .primary))
      .disabled(isBusy)
      .padding(26)
    }
  }

  private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.title3.bold())
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 26)
  }

  private func section(title: String, subtitle: String, photos: [SessionPhoto]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      header(title: title, subtitle: subtitle)
      PhotoGridCells(photos: photos) { id in
        vm.restoreMany(ids: [id])
      }
    }
  }
}
