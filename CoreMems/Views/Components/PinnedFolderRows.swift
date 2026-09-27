// CoreMems/Views/Components/PinnedFolderRows.swift
import SwiftUI

extension EnvironmentValues {
  /// Opens a folder's contents; rows push a folder with a button because links don't work in edit mode.
  @Entry var openFolder: (AlbumGroup) -> Void = { _ in }
}

/// A pinnable, foldered album row shared by every screen that lists albums: Pinned Albums
/// settings and the session's album picker. Pinning toggles from the pin icon or the
/// long-press menu, never a plain row tap, so dragging a row to reorder can't unpin it.
struct PinnedEntryRow: View {
  let entry: PinnedDisplayItem
  /// The containing folders, outermost first; shown when rows are listed outside their folder.
  var folderPath: [AlbumGroup] = []
  let pinnedIDs: Set<String>
  let pinnedAlbums: PinnedAlbumsViewModel
  /// Assigns the tapped album when set; nil keeps rows static, as in Pinned Albums settings.
  var onSelectAlbum: ((AlbumOption) -> Void)? = nil
  /// Marks an already-selected album, e.g. a checkmark for a photo's current albums.
  var isSelected: (AlbumOption) -> Bool = { _ in false }
  @Environment(\.openFolder) private var openFolder

  private var isPinned: Bool { pinnedIDs.contains(entry.id) }

  var body: some View {
    if case .collapsedFolder(_, let albums) = entry {
      CollapsedFolderRow(
        entry: entry, albums: albums, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
        onSelectAlbum: onSelectAlbum, isSelected: isSelected)
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
      let canPin = album.ref.kind == .existing
      AlbumRow(
        album: album, isPinned: isPinned, folderPath: folderPath,
        onTogglePin: canPin ? { pinnedAlbums.toggle(entry.id) } : nil,
        onTap: onSelectAlbum.map { select in { select(album) } }
      ) {
        if isSelected(album) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.title3)
        }
      }
      .contextMenu {
        if canPin {
          AlbumPinButton(isPinned: isPinned) { pinnedAlbums.toggle(entry.id) }
        }
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
  var onSelectAlbum: ((AlbumOption) -> Void)? = nil
  var isSelected: (AlbumOption) -> Bool = { _ in false }

  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(albums) {
        PinnedEntryRow(
          entry: .album($0), pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
          onSelectAlbum: onSelectAlbum, isSelected: isSelected)
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
struct PinnedGroupView: View {
  let group: AlbumGroup
  let albums: [AlbumOption]
  let groups: [AlbumGroup]
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  /// Recently used album IDs, newest first.
  let recentAlbumIDs: [String]
  var onSelectAlbum: ((AlbumOption) -> Void)? = nil
  var isSelected: (AlbumOption) -> Bool = { _ in false }

  @State private var openedGroup: AlbumGroup?

  private var canReorder: Bool { pinnedAlbums.sort == .myOrder && !pinnedAlbums.isLoading }

  private var pinnedIdentifiers: [String] {
    pinnedAlbums.orderedIdentifiers(recents: recentAlbumIDs)
  }

  private var subfolders: [PinnedDisplayItem] {
    let groupsByID = groups.indexed(by: \.identifier)
    return group.groupIdentifiers.compactMap { groupsByID[$0].map(PinnedDisplayItem.folder) }
  }

  private var pinnedEntries: [PinnedDisplayItem] {
    let albumsByID = albums.indexed(by: \.ref.identifier)
    let inGroup = Set(group.albumIdentifiers)
    return pinnedIdentifiers.filter(inGroup.contains).compactMap {
      albumsByID[$0].map(PinnedDisplayItem.album)
    }
  }

  private var otherEntries: [PinnedDisplayItem] {
    let albumsByID = albums.indexed(by: \.ref.identifier)
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
            PinnedEntryRow(
              entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
              onSelectAlbum: onSelectAlbum, isSelected: isSelected)
          }
        }
      }
      if !pinnedEntries.isEmpty {
        Section("Pinned") {
          ForEach(pinnedEntries) {
            PinnedEntryRow(
              entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
              onSelectAlbum: onSelectAlbum, isSelected: isSelected)
          }
          .reorderable(
            canReorder, ids: pinnedEntries.map(\.id),
            onReorder: { pinnedAlbums.reorder($0) })
        }
      }
      if !otherEntries.isEmpty {
        Section {
          ForEach(otherEntries) {
            PinnedEntryRow(
              entry: $0, pinnedIDs: pinnedIDs, pinnedAlbums: pinnedAlbums,
              onSelectAlbum: onSelectAlbum, isSelected: isSelected)
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
      if let path = groups.folderPaths[group.id] {
        FolderPathLabel(path: path + [group])
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.bar)
      }
    }
    .environment(\.openFolder) { openedGroup = $0 }
    .navigationDestination(item: $openedGroup) {
      PinnedGroupView(
        group: $0, albums: albums, groups: groups, pinnedAlbums: pinnedAlbums,
        recentAlbumIDs: recentAlbumIDs, onSelectAlbum: onSelectAlbum, isSelected: isSelected)
    }
    .navigationTitle(group.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}
