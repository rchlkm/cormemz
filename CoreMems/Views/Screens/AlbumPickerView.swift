// CoreMems/Views/Screens/AlbumPickerView.swift
import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>

  /// The whole library, nil until loaded. Listed on search or "Show all albums".
  var libraryAlbums: [AlbumOption]? = []
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @State private var showAllAlbums = false
  /// Membership when the sheet opened; rows keep their section while it is open, only the checkmark changes.
  @State private var openingAssignedRefs: Set<AlbumRef>?
  @Environment(\.dismiss) private var dismiss

  private struct Results {
    var alreadyIn: [AlbumOption] = []
    var new: [AlbumOption] = []
    var pinned: [AlbumOption] = []
    var recent: [AlbumOption] = []
    var all: [AlbumOption] = []
  }

  /// One pass over `albums`, then `libraryAlbums`, so per-keystroke search stays cheap.
  /// Library albums outside `albums` are listed only when searching or after "Show all albums".
  private func computeResults(for search: AlbumSearchQuery) -> Results {
    var results = Results()
    let sectionRefs = openingAssignedRefs ?? assignedRefs
    let pinnedIDs = Set(pinnedAlbums.identifiers)

    for album in albums where search.matches(album) {
      if sectionRefs.contains(album.ref) {
        results.alreadyIn.append(album)
      } else if album.ref.kind == .pendingNew {
        results.new.append(album)
      } else if pinnedIDs.contains(album.ref.identifier) {
        results.pinned.append(album)
      } else {
        results.recent.append(album)
      }
    }

    if let libraryAlbums, !libraryAlbums.isEmpty {
      let loadedIDs = Set(albums.map(\.ref.identifier))
      for album in libraryAlbums where !loadedIDs.contains(album.ref.identifier) {
        guard search.matches(album) else { continue }
        if sectionRefs.contains(album.ref) {
          results.alreadyIn.append(album)
        } else if search.isSearching || showAllAlbums || assignedRefs.contains(album.ref) {
          results.all.append(album)
        }
      }
    }

    return results
  }

  var body: some View {
    NavigationStack {
      AlbumSearchList(
        albums: albums,
        libraryAlbums: libraryAlbums,
        isLoading: libraryAlbums == nil && albums.isEmpty,
        onCreate: onCreate,
        isReorderable: pinnedAlbums.sort == .myOrder
      ) { search in
        let results = computeResults(for: search)

        if !results.alreadyIn.isEmpty {
          Section("Already in") {
            ForEach(results.alreadyIn) { albumRow($0) }
          }
        }

        if !results.new.isEmpty {
          Section("New albums") {
            ForEach(results.new) { albumRow($0) }
          }
        }

        if !results.pinned.isEmpty {
          Section {
            ForEach(results.pinned) { albumRow($0) }
              .reorderable(
                pinnedAlbums.sort == .myOrder && !search.isSearching,
                ids: results.pinned.map(\.ref.identifier), onReorder: { pinnedAlbums.reorder($0) })
          } header: {
            PinnedSectionHeader(sort: $pinnedAlbums.sort)
          }
        }

        if !results.recent.isEmpty {
          Section("Recent") {
            ForEach(results.recent) { albumRow($0) }
          }
        }

        if !results.all.isEmpty {
          Section("All Albums") {
            ForEach(results.all) { albumRow($0) }
          }
        } else if !search.isSearching && results.alreadyIn.isEmpty && results.new.isEmpty
          && results.pinned.isEmpty && results.recent.isEmpty
        {
          Section { AlbumSearchHint() }
        }

        if libraryAlbums != nil && !showAllAlbums && !search.isSearching {
          Section {
            Button {
              showAllAlbums = true
            } label: {
              Label("Show all albums", systemImage: "ellipsis.circle")
            }
          }
        }
      }
      .onAppear { openingAssignedRefs = openingAssignedRefs ?? assignedRefs }
      .navigationTitle("Albums")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private func albumRow(_ album: AlbumOption) -> some View {
    let isPinned = pinnedAlbums.identifiers.contains(album.ref.identifier)
    return AlbumRow(
      album: album, isPinned: isPinned,
      onTogglePin: album.ref.kind == .existing
        ? { pinnedAlbums.toggle(album.ref.identifier) } : nil,
      onTap: { onToggle(album.ref) }
    ) {
      if assignedRefs.contains(album.ref) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.title3)
      }
    }
    .swipeActions {
      if album.ref.kind == .existing {
        AlbumPinButton(isPinned: pinnedAlbums.identifiers.contains(album.ref.identifier)) {
          pinnedAlbums.toggle(album.ref.identifier)
        }
        .tint(.orange)
      }
    }
  }
}
