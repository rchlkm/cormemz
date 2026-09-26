// CoreMems/Views/Sheets/PinnedAlbumsSettingsView.swift
import SwiftUI

/// Lets the user pin the albums that show first in the picker and strip, browse album groups to
/// find them, and arrange them by hand. Pushed onto the Settings navigation stack.
/// The search field also creates and pins a new album (see `AlbumSearchList`).
struct PinnedAlbumsSettingsView: View {
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  /// The pinned album IDs in display order.
  let pinnedIdentifiers: [String]

  @State private var openedGroup: AlbumGroup?

  /// Pinned albums in display order, then the groups and unpinned albums. Pinned albums sharing a
  /// folder collapse into it; subfolders and albums inside a group are listed under it. Search
  /// flattens both, listing every match on its own.
  private func split(for search: AlbumSearchQuery) -> (
    pinned: [PinnedDisplayItem], library: [PinnedDisplayItem]
  ) {
    let albumsByID = pinnedAlbums.albums.indexed(by: \.ref.identifier)
    let groupsByID = pinnedAlbums.groups.indexed(by: \.identifier)
    let pinnedSet = Set(pinnedIdentifiers)
    let groupedAlbumIDs = Set(pinnedAlbums.groups.flatMap(\.albumIdentifiers))
    let subgroupIDs = Set(pinnedAlbums.groups.flatMap(\.groupIdentifiers))
    let pinned =
      search.isSearching
      ? pinnedIdentifiers.compactMap { id -> PinnedDisplayItem? in
        if let album = albumsByID[id], search.matches(album) { return .album(album) }
        return nil
      }
      : PinnedDisplayItem.items(
        identifiers: pinnedIdentifiers, albums: pinnedAlbums.albums,
        groups: pinnedAlbums.groups)
    let groups = pinnedAlbums.groups.filter {
      !pinnedSet.contains($0.identifier)
        && (search.isSearching || !subgroupIDs.contains($0.identifier))
        && search.matches($0)
    }
    let albums = pinnedAlbums.albums.filter {
      !pinnedSet.contains($0.ref.identifier)
        && (search.isSearching || !groupedAlbumIDs.contains($0.ref.identifier))
        && search.matches($0)
    }
    return (pinned, groups.map(PinnedDisplayItem.folder) + albums.map(PinnedDisplayItem.album))
  }

  var body: some View {
    AlbumSearchList(
      albums: pinnedAlbums.albums,
      isLoading: pinnedAlbums.isLoading && pinnedAlbums.albums.isEmpty,
      isCreating: pinnedAlbums.isCreating,
      onCreate: { pinnedAlbums.createAndPin(name: $0) },
      isReorderable: pinnedAlbums.sort == .myOrder
    ) { search in
      let (pinned, library) = split(for: search)
      let paths = search.isSearching ? pinnedAlbums.folderPathsByChildID : [:]
      let pinnedIDs = Set(pinnedAlbums.identifiers)
      let identifiersByItem = Dictionary(
        pinned.map { ($0.id, $0.pinnedIdentifiers) }, uniquingKeysWith: { first, _ in first })

      if let creationError = pinnedAlbums.creationError {
        Section {
          Text(creationError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      if !search.isSearching {
        Section {
          Text(
            "Pinned albums show up first when adding a photo to an album, so you can rotate through the ones you use most instead of scrolling your whole library. Open a group to pin its albums."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
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
            pinnedAlbums.sort == .myOrder && !search.isSearching,
            ids: pinned.map(\.id),
            onReorder: { pinnedAlbums.reorder($0.flatMap { identifiersByItem[$0] ?? [] }) })
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
    .environment(\.openFolder) { openedGroup = $0 }
    .navigationDestination(item: $openedGroup) {
      PinnedGroupView(group: $0, pinnedAlbums: pinnedAlbums, pinnedIdentifiers: pinnedIdentifiers)
    }
  }
}

extension PinnedDisplayItem {
  var title: String {
    switch self {
    case .album(let album): return album.name
    case .folder(let group), .collapsedFolder(let group, _): return group.name
    }
  }

  var subtitle: String? {
    switch self {
    case .album(let album):
      return album.countLabel
    case .folder(let group):
      let parts = [
        (group.groupIdentifiers.count, "folder"), (group.albumIdentifiers.count, "album"),
      ]
      return parts.filter { $0.0 > 0 }
        .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        .joined(separator: " · ")
    case .collapsedFolder(let group, let albums):
      return "\(albums.count) of \(group.albumIdentifiers.count) albums pinned"
    }
  }
}

extension EnvironmentValues {
  /// Opens a folder's contents; rows push a folder with a button because links don't work in edit mode.
  @Entry fileprivate var openFolder: (AlbumGroup) -> Void = { _ in }
}

/// A pinnable row. Pinning toggles from the pin icon or the long-press menu, never a plain row
/// tap, so dragging a row to reorder can't unpin it.
private struct PinnedEntryRow: View {
  let entry: PinnedDisplayItem
  /// The containing folders, outermost first; shown when rows are listed outside their folder.
  var folderPath: [AlbumGroup] = []
  let pinnedIDs: Set<String>
  let pinnedAlbums: PinnedAlbumsViewModel
  @Environment(\.openFolder) private var openFolder

  private var isPinned: Bool { pinnedIDs.contains(entry.id) }

  var body: some View {
    if case .collapsedFolder(_, let albums) = entry {
      CollapsedFolderRow(
        entry: entry, albums: albums, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums)
    } else {
      pinnableRow
    }
  }

  @ViewBuilder
  private var pinnableRow: some View {
    switch entry {
    case .folder(let group):
      FolderRow(
        title: group.name, subtitle: entry.subtitle, folderPath: folderPath,
        onOpen: { openFolder(group) })
    case .album(let album):
      AlbumRow(
        album: album, isPinned: isPinned, folderPath: folderPath,
        onTogglePin: { pinnedAlbums.toggle(entry.id) }
      )
      .contextMenu {
        Button(
          isPinned ? "Unpin" : "Pin",
          systemImage: isPinned ? "pin.slash" : "pin"
        ) { pinnedAlbums.toggle(entry.id) }
      }
    case .collapsedFolder:
      EmptyView()
    }
  }
}

/// A folder standing in for several pinned albums; expands to show them.
private struct CollapsedFolderRow: View {
  let entry: PinnedDisplayItem
  let albums: [AlbumOption]
  let pinnedIDs: Set<String>
  let pinnedAlbums: PinnedAlbumsViewModel

  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(albums) {
        PinnedEntryRow(entry: .album($0), pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums)
      }
    } label: {
      HStack(spacing: 12) {
        FolderIcon()

        VStack(alignment: .leading, spacing: 1) {
          Text(entry.title)
          if let subtitle = entry.subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.vertical, 2)
    }
    .contextMenu {
      Button("Unpin All", systemImage: "pin.slash") {
        for album in albums { pinnedAlbums.toggle(album.ref.identifier) }
      }
    }
  }
}

/// The subfolders, then the albums inside a group: pinned ones first, in display order, then the
/// rest in the folder's order. Albums can be pinned and reordered here.
private struct PinnedGroupView: View {
  let group: AlbumGroup
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  /// The pinned album IDs in display order.
  let pinnedIdentifiers: [String]

  @State private var openedGroup: AlbumGroup?

  private var subfolders: [PinnedDisplayItem] {
    let groupsByID = pinnedAlbums.groups.indexed(by: \.identifier)
    return group.groupIdentifiers.compactMap { groupsByID[$0].map(PinnedDisplayItem.folder) }
  }

  private var pinnedEntries: [PinnedDisplayItem] {
    let albumsByID = pinnedAlbums.albums.indexed(by: \.ref.identifier)
    let inGroup = Set(group.albumIdentifiers)
    return pinnedIdentifiers.filter(inGroup.contains).compactMap {
      albumsByID[$0].map(PinnedDisplayItem.album)
    }
  }

  private var otherEntries: [PinnedDisplayItem] {
    let albumsByID = pinnedAlbums.albums.indexed(by: \.ref.identifier)
    let pinned = Set(pinnedIdentifiers)
    return group.albumIdentifiers.filter { !pinned.contains($0) }.compactMap {
      albumsByID[$0].map(PinnedDisplayItem.album)
    }
  }

  var body: some View {
    let pinnedIDs = Set(pinnedAlbums.identifiers)
    let subfolders = subfolders
    let pinnedEntries = pinnedEntries
    let otherEntries = otherEntries
    return List {
      if !subfolders.isEmpty {
        Section {
          ForEach(subfolders) {
            PinnedEntryRow(entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums)
          }
        }
      }
      if !pinnedEntries.isEmpty {
        Section("Pinned") {
          ForEach(pinnedEntries) {
            PinnedEntryRow(entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums)
          }
          .reorderable(
            pinnedAlbums.sort == .myOrder, ids: pinnedEntries.map(\.id),
            onReorder: { pinnedAlbums.reorder($0) })
        }
      }
      if !otherEntries.isEmpty {
        Section {
          ForEach(otherEntries) {
            PinnedEntryRow(entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums)
          }
        } header: {
          if !pinnedEntries.isEmpty { Text("Albums") }
        }
      }
    }
    .environment(\.editMode, .constant(pinnedAlbums.sort == .myOrder ? .active : .inactive))
    .overlay {
      if subfolders.isEmpty && pinnedEntries.isEmpty && otherEntries.isEmpty {
        ContentUnavailableView("No Albums", systemImage: "folder")
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if let path = pinnedAlbums.folderPathsByChildID[group.id] {
        FolderPathLabel(path: path + [group])
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.bar)
      }
    }
    .environment(\.openFolder) { openedGroup = $0 }
    .navigationDestination(item: $openedGroup) {
      PinnedGroupView(group: $0, pinnedAlbums: pinnedAlbums, pinnedIdentifiers: pinnedIdentifiers)
    }
    .navigationTitle(group.name)
    .navigationBarTitleDisplayMode(.inline)
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
      pinnedIdentifiers: ["1", "g1"]
    )
  }
}
