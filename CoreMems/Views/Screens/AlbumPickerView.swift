// CoreMems/Views/Screens/AlbumPickerView.swift
import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>

  /// The whole library, nil until loaded. Listed on search or "Show all albums".
  var libraryAlbums: [AlbumOption]? = []
  /// Photos folders of albums, for browsing the library the same way Pinned Albums settings does.
  var groups: [AlbumGroup] = []
  /// Recently used album IDs, newest first.
  var recentAlbumIDs: [String] = []
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @State private var showAllAlbums = false
  @State private var openedGroup: AlbumGroup?
  /// Membership when the sheet opened; rows keep their section while it is open, only the checkmark changes.
  @State private var openingAssignedRefs: Set<AlbumRef>?
  @Environment(\.dismiss) private var dismiss

  private struct Results {
    var alreadyIn: [AlbumOption] = []
    var new: [AlbumOption] = []
    var recent: [AlbumOption] = []
    var pinned: [PinnedDisplayItem] = []
    var library: [PinnedDisplayItem] = []
  }

  /// One pass over `albums`, then `libraryAlbums`, so per-keystroke search stays cheap. Library
  /// albums outside `albums` are folder-browsable only once searching or after "Show all albums",
  /// except one already assigned this photo mid-visit, which stays visible so its checkmark can
  /// keep showing.
  private func computeResults(for search: AlbumSearchQuery) -> Results {
    var results = Results()
    let sectionRefs = openingAssignedRefs ?? assignedRefs
    let pinnedIDs = Set(pinnedAlbums.identifiers)

    for album in albums where search.matches(album) {
      if sectionRefs.contains(album.ref) {
        results.alreadyIn.append(album)
      } else if album.ref.kind == .pendingNew {
        results.new.append(album)
      } else if !pinnedIDs.contains(album.ref.identifier) {
        results.recent.append(album)
      }
    }

    let alreadyAssigned = Set(sectionRefs.map(\.identifier))
    results.pinned = PinnedDisplayItem.sections(
      albums: albums, groups: groups,
      pinnedIdentifiers: pinnedAlbums.orderedIdentifiers(recents: recentAlbumIDs),
      search: search, excluding: alreadyAssigned
    ).pinned

    if let libraryAlbums, !libraryAlbums.isEmpty {
      let loadedIDs = Set(albums.map(\.ref.identifier))
      let strays = libraryAlbums.filter { !loadedIDs.contains($0.ref.identifier) }

      for album in strays where sectionRefs.contains(album.ref) && search.matches(album) {
        results.alreadyIn.append(album)
      }

      let revealsLibrary =
        search.isSearching || showAllAlbums
        || strays.contains { assignedRefs.contains($0.ref) && !sectionRefs.contains($0.ref) }
      if revealsLibrary {
        results.library = PinnedDisplayItem.sections(
          albums: strays, groups: groups, pinnedIdentifiers: pinnedAlbums.identifiers,
          search: search, excluding: alreadyAssigned
        ).library
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
        let paths = search.isSearching ? groups.folderPaths : [:]
        let pinnedIDs = Set(pinnedAlbums.identifiers)

        if !results.alreadyIn.isEmpty {
          Section("Already in") {
            ForEach(results.alreadyIn) { entryRow(.album($0), folderPath: [], pinnedIDs: pinnedIDs) }
          }
        }

        if !results.new.isEmpty {
          Section("New albums") {
            ForEach(results.new) { entryRow(.album($0), folderPath: [], pinnedIDs: pinnedIDs) }
          }
        }

        if !results.pinned.isEmpty {
          Section {
            ForEach(results.pinned) { entryRow($0, folderPath: paths[$0.id] ?? [], pinnedIDs: pinnedIDs) }
              .reorderable(
                pinnedAlbums.sort == .myOrder && !search.isSearching,
                ids: results.pinned.map(\.id),
                onReorder: { pinnedAlbums.reorder(PinnedDisplayItem.flattenReorder($0, items: results.pinned)) })
          } header: {
            PinnedSectionHeader(sort: $pinnedAlbums.sort)
          }
        }

        if !results.recent.isEmpty {
          Section("Recent") {
            ForEach(results.recent) { entryRow(.album($0), folderPath: [], pinnedIDs: pinnedIDs) }
          }
        }

        if !results.library.isEmpty {
          Section("All Albums") {
            ForEach(results.library) { entryRow($0, folderPath: paths[$0.id] ?? [], pinnedIDs: pinnedIDs) }
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
      .environment(\.openFolder) { openedGroup = $0 }
      .navigationDestination(item: $openedGroup) {
        PinnedGroupView(
          group: $0, albums: libraryAlbums ?? albums, groups: groups, pinnedAlbums: pinnedAlbums,
          recentAlbumIDs: recentAlbumIDs, onSelectAlbum: { onToggle($0.ref) },
          isSelected: { assignedRefs.contains($0.ref) })
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

  private func entryRow(_ entry: PinnedDisplayItem, folderPath: [AlbumGroup], pinnedIDs: Set<String>)
    -> some View
  {
    PinnedEntryRow(
      entry: entry, folderPath: folderPath, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
      onSelectAlbum: { onToggle($0.ref) }, isSelected: { assignedRefs.contains($0.ref) })
  }
}
