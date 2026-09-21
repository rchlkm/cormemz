// CoreMems/Views/Screens/PendingReviewView.swift
import SwiftUI

struct PendingReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var selected: Set<String> = []

  private var items: [SessionPhoto] { vm.pendingItems }
  private var conversions: [SessionPhoto] { vm.pendingConversions }
  private var hasItems: Bool { !items.isEmpty }

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
              photos: items,
              favoritesCount: items.filter(\.isFavorite).count)
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

      if let deletionError = vm.deletionError {
        Text(deletionError)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 26)
      }

      Button {
        Task { await vm.confirmDeletion() }
      } label: {
        if vm.isDeleting {
          ProgressView()
        } else {
          Text(
            hasItems
              ? "Delete \(items.count) photo\(items.count == 1 ? "" : "s")" : "Finish session"
          )
        }
      }
      .buttonStyle(ActionButtonStyle(role: hasItems ? .destructive : .primary))
      .disabled(vm.isDeleting)
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

  private func section(
    title: String, subtitle: String, photos: [SessionPhoto], favoritesCount: Int = 0
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      header(title: title, subtitle: subtitle)
      if favoritesCount > 0 {
        Label(
          "\(favoritesCount) \(favoritesCount == 1 ? "is" : "are") marked as a favorite",
          systemImage: "heart.fill"
        )
        .font(.footnote)
        .foregroundStyle(.pink)
        .padding(.horizontal, 26)
        .padding(.top, 8)
      }
      PhotoGridCells(photos: photos) { id in
        vm.restoreMany(ids: [id])
      }
    }
  }
}
