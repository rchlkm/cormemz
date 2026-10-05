// CoreMems/Views/Sheets/PinnedAlbumsSettingsView.swift
import SwiftUI

/// Lets the user pin the albums that show first in the picker and strip, browse album groups to
/// find them, and arrange them by hand. Pushed onto the Settings navigation stack.
/// The search field also creates and pins a new album (see `AlbumSearchList`).
struct PinnedAlbumsSettingsView: View {
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  /// Recently used album IDs, newest first.
  let recentAlbumIDs: [String]

  @State private var openedGroup: AlbumGroup?
  @State private var hasLoaded = false

  /// Moves wait for this visit's load to finish, so a reload can't reshuffle rows mid-drag.
  private var canReorder: Bool { pinnedAlbums.sort == .myOrder && hasLoaded }

  var body: some View {
    AlbumSearchList(
      albums: pinnedAlbums.albums,
      isLoading: pinnedAlbums.isLoading && pinnedAlbums.albums.isEmpty,
      isCreating: pinnedAlbums.isCreating,
      onCreate: { pinnedAlbums.createAndPin(name: $0) },
      isReorderable: pinnedAlbums.sort == .myOrder
    ) { search in
      let sections = PinnedDisplayItem.sections(
        albums: pinnedAlbums.albums, groups: pinnedAlbums.groups,
        pinnedIdentifiers: pinnedAlbums.orderedIdentifiers(recents: recentAlbumIDs), search: search)
      let pinned = sections.pinned
      let library = sections.library
      let paths = search.isSearching ? pinnedAlbums.folderPathsByChildID : [:]
      let pinnedIDs = Set(pinnedAlbums.identifiers)

      if let creationError = pinnedAlbums.creationError {
        Section {
          Text(creationError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      if !pinned.isEmpty {
        Section {
          ForEach(pinned) {
            PinnedEntryRow(
              entry: $0, folderPath: paths[$0.id] ?? [], pinnedIDs: pinnedIDs,
              pinnedAlbums: pinnedAlbums)
          }
          .reorderable(
            canReorder && !search.isSearching,
            ids: pinned.map(\.id),
            onReorder: {
              PinnedLoadTrace.log("reorder dropped")
              pinnedAlbums.reorder(PinnedDisplayItem.flattenReorder($0, items: pinned))
            })
        } header: {
          PinnedSectionHeader(sort: $pinnedAlbums.sort)
        }
      }

      if !library.isEmpty {
        Section("Albums & Groups") {
          ForEach(library) {
            PinnedEntryRow(
              entry: $0, folderPath: paths[$0.id] ?? [], pinnedIDs: pinnedIDs,
              pinnedAlbums: pinnedAlbums)
          }
        }
      } else if !search.isSearching && pinned.isEmpty {
        Section { AlbumSearchHint() }
      }
    }
    .navigationTitle("Pinned Albums")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: pinnedAlbums.isLoading) { _, isLoading in
      if !isLoading {
        hasLoaded = true
        PinnedLoadTrace.log("handles enabled")
      }
    }
    .onAppear { PinnedLoadTrace.begin() }
    .onDisappear { PinnedLoadTrace.end() }
    .environment(\.openFolder) { openedGroup = $0 }
    .navigationDestination(item: $openedGroup) {
      PinnedGroupView(
        group: $0, albums: pinnedAlbums.albums, groups: pinnedAlbums.groups,
        pinnedAlbums: pinnedAlbums, recentAlbumIDs: recentAlbumIDs)
    }
  }
}

#Preview {
  NavigationStack {
    PinnedAlbumsSettingsView(
      pinnedAlbums: .mock(
        albums: [
          AlbumOption(ref: .existing(localIdentifier: "1"), name: "Trip 2024", assetCount: 128),
          AlbumOption(ref: .existing(localIdentifier: "2"), name: "Family", assetCount: 842),
        ],
        groups: [AlbumGroup(identifier: "g1", name: "Views", albumIdentifiers: ["1", "2"])],
        pinned: ["1", "g1"]),
      recentAlbumIDs: []
    )
  }
}
