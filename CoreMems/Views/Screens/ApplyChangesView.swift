// CoreMems/Views/Screens/ApplyChangesView.swift
import SwiftUI

struct ApplyChangesView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var selected: Set<String> = []
  @State private var filter: Filter = .all

  private enum Filter: String, CaseIterable, Identifiable {
    case all = "All"
    case delete = "Delete"
    case convert = "Convert"
    case edit = "Edited"
    var id: String { rawValue }

    /// The summary shown when this is the only kind of change; `nil` for `.all`.
    func summary(count: Int) -> (title: String, symbol: String, tint: Color)? {
      switch self {
      case .all: return nil
      case .delete: return ("\(count) to delete", "trash", Decision.pendingDelete.tint)
      case .convert:
        return ("\(count) to convert", "livephoto.slash", Decision.convertToStill.tint)
      case .edit: return ("\(count) edited", EditStyle.symbol, EditStyle.tint)
      }
    }
  }

  private var items: [SessionPhoto] { vm.pendingItems }
  private var conversions: [SessionPhoto] { vm.pendingConversions }
  private var marked: [SessionPhoto] { items + conversions + vm.pendingEdits }
  private var hasItems: Bool { !items.isEmpty }
  private var favoritesCount: Int { items.filter(\.isFavorite).count }

  /// "All" plus each kind of change present.
  private var filters: [Filter] {
    Filter.allCases.filter { $0 == .all || !photos(for: $0).isEmpty }
  }
  /// Only offered when more than one kind is present; otherwise everything is shown.
  private var showsFilter: Bool { filters.count > 2 }
  private var activeFilter: Filter { showsFilter ? filter : .all }

  private func photos(for filter: Filter) -> [SessionPhoto] {
    switch filter {
    case .all: return marked
    case .delete: return items
    case .convert: return conversions
    case .edit: return vm.pendingEdits
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "Before you go", onBack: { vm.screen = .browse })

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
        Task { await vm.applyChanges() }
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
      .accessibilityIdentifier(AccessibilityID.applyConfirm)
      .disabled(vm.isDeleting)
      .padding(26)
    }
  }

  /// Swipeable pages keep each grid alive, so switching filters doesn't reload thumbnails.
  @ViewBuilder
  private var pages: some View {
    if showsFilter {
      TabView(selection: $filter) {
        ForEach(filters) { option in
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
      } else if let summary = filters.last?.summary(count: marked.count) {
        summaryLabel(summary.title, symbol: summary.symbol, tint: summary.tint)
      }
      if hasItems || !conversions.isEmpty {
        Text("Deleted items stay in Recently Deleted for 30 days.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if favoritesCount > 0 && (activeFilter == .all || activeFilter == .delete) {
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
      ForEach(filters) { option in
        Text("\(option.rawValue) \(photos(for: option).count)").tag(option)
      }
    }
    .pickerStyle(.segmented)
  }

  private func summaryLabel(_ title: String, symbol: String, tint: Color) -> some View {
    Label {
      Text(title)
    } icon: {
      Image(systemName: symbol).foregroundStyle(tint)
    }
    .font(.title3.bold())
  }
}
