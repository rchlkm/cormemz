// CoreMems/Views/Screens/PendingReviewView.swift
import SwiftUI

struct PendingReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var selected: Set<String> = []
  @State private var filter: Filter = .all

  private enum Filter: String, CaseIterable, Identifiable {
    case all = "All"
    case delete = "Delete"
    case convert = "Convert"
    var id: String { rawValue }
  }

  private var items: [SessionPhoto] { vm.pendingItems }
  private var conversions: [SessionPhoto] { vm.pendingConversions }
  private var marked: [SessionPhoto] { items + conversions }
  private var hasItems: Bool { !items.isEmpty }
  private var favoritesCount: Int { items.filter(\.isFavorite).count }

  /// Only offered when both kinds are present; otherwise everything is shown.
  private var showsFilter: Bool { hasItems && !conversions.isEmpty }
  private var activeFilter: Filter { showsFilter ? filter : .all }

  private func photos(for filter: Filter) -> [SessionPhoto] {
    switch filter {
    case .all: return marked
    case .delete: return items
    case .convert: return conversions
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "Before you go", onBack: { vm.screen = .review })

      if vm.reachedSessionCap {
        Label(
          "You've reviewed \(SessionSettings.maxPhotosPerSession) photos. Confirm your changes, then start another session to keep going.",
          systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 26)
        .padding(.bottom, 8)
      }

      if marked.isEmpty {
        ScrollView {
          header(
            title: "Nothing marked for deletion",
            subtitle: "You kept all \(vm.keptCount) photos from this session. Nothing will be deleted."
          )
          .padding(.top, 4)
        }
      } else {
        summary
        pages
      }

      if let deletionError = vm.deletionError {
        Text(deletionError)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 26)
      }

      Button {
        Task { await vm.confirmSession() }
      } label: {
        if vm.isDeleting {
          ProgressView()
        } else {
          Text(
            marked.isEmpty
              ? "Finish session" : "Confirm \(marked.count) change\(marked.count == 1 ? "" : "s")"
          )
        }
      }
      .buttonStyle(ActionButtonStyle(role: hasItems ? .destructive : .primary))
      .accessibilityIdentifier(AccessibilityID.pendingConfirm)
      .disabled(vm.isDeleting)
      .padding(26)
    }
  }

  /// Swipeable pages keep each grid alive, so switching filters doesn't reload thumbnails.
  @ViewBuilder
  private var pages: some View {
    if showsFilter {
      TabView(selection: $filter) {
        ForEach(Filter.allCases) { option in
          gridPage(photos(for: option)).tag(option)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.default, value: filter)
    } else {
      gridPage(marked)
    }
  }

  private func gridPage(_ photos: [SessionPhoto]) -> some View {
    ScrollView {
      PhotoGridCells(photos: photos, showsDecisionTags: true) { id in
        vm.restoreMany(ids: [id])
      }
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

  private var summary: some View {
    VStack(alignment: .leading, spacing: 8) {
      if showsFilter {
        filterPicker
      } else if hasItems {
        summaryLabel("\(items.count) to delete", symbol: "trash", decision: .pendingDelete)
      } else {
        summaryLabel(
          "\(conversions.count) to convert", symbol: "livephoto.slash",
          decision: .convertToStill)
      }
      Text("Deleted items stay in Recently Deleted for 30 days.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if favoritesCount > 0 && activeFilter != .convert {
        Label(
          "\(favoritesCount) \(favoritesCount == 1 ? "is" : "are") marked as a favorite",
          systemImage: "heart.fill"
        )
        .font(.footnote)
        .foregroundStyle(.pink)
      }
    }
    .padding(.horizontal, 26)
    .padding(.top, 4)
  }

  private var filterPicker: some View {
    Picker("Show", selection: $filter) {
      ForEach(Filter.allCases) { option in
        Text("\(option.rawValue) \(photos(for: option).count)").tag(option)
      }
    }
    .pickerStyle(.segmented)
  }

  private func summaryLabel(_ title: String, symbol: String, decision: ReviewDecision)
    -> some View
  {
    Label {
      Text(title)
    } icon: {
      Image(systemName: symbol).foregroundStyle(decision.tint)
    }
    .font(.title3.bold())
  }
}
