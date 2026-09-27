// CoreMems/Models/PinnedDisplayItem.swift
import Foundation

/// An album-list entry: an album, a browsable folder, or a folder standing in for several
/// pinned albums that share it.
enum PinnedDisplayItem: Identifiable, Equatable {
  case album(AlbumOption)
  case folder(AlbumGroup)
  case collapsedFolder(AlbumGroup, albums: [AlbumOption])

  /// Pinned albums from one folder collapse into it once there are this many.
  static let collapseThreshold = 2

  var id: String {
    switch self {
    case .album(let album): return album.ref.identifier
    case .folder(let group): return group.identifier
    case .collapsedFolder(let group, _): return "collapsed:" + group.identifier
    }
  }

  /// The pin identifiers this item stands for, in order.
  var pinnedIdentifiers: [String] {
    switch self {
    case .album, .folder: return [id]
    case .collapsedFolder(_, let albums): return albums.map(\.ref.identifier)
    }
  }

  /// Expands a reordered list of display item ids back into raw pinned identifiers: a dragged
  /// id may be a collapsed folder standing in for several.
  static func flattenReorder(_ ids: [String], items: [PinnedDisplayItem]) -> [String] {
    let identifiersByItem = Dictionary(
      items.map { ($0.id, $0.pinnedIdentifiers) }, uniquingKeysWith: { first, _ in first })
    return ids.flatMap { identifiersByItem[$0] ?? [] }
  }

  /// The pinned albums in `identifiers`, in order, as display items. Albums sharing a direct
  /// parent collapse into one folder item at the first member's position. Other identifiers
  /// are ignored.
  static func items(
    identifiers: [String], albums: [AlbumOption], groups: [AlbumGroup]
  ) -> [PinnedDisplayItem] {
    let albumsByID = albums.indexed(by: \.ref.identifier)
    let parents = groups.parentsByChildID

    var members: [String: [AlbumOption]] = [:]
    for id in identifiers {
      guard let album = albumsByID[id], let parent = parents[id] else { continue }
      members[parent.identifier, default: []].append(album)
    }

    var collapsed: Set<String> = []
    var items: [PinnedDisplayItem] = []
    for id in identifiers {
      guard let album = albumsByID[id] else { continue }
      if let parent = parents[id], let siblings = members[parent.identifier],
        siblings.count >= collapseThreshold
      {
        if collapsed.insert(parent.identifier).inserted {
          items.append(.collapsedFolder(parent, albums: siblings))
        }
      } else {
        items.append(.album(album))
      }
    }
    return items
  }
}

extension Array where Element == AlbumGroup {
  /// The folder directly containing each album or subfolder, by identifier.
  var parentsByChildID: [String: AlbumGroup] {
    var parents: [String: AlbumGroup] = [:]
    for group in self {
      for childID in group.albumIdentifiers + group.groupIdentifiers { parents[childID] = group }
    }
    return parents
  }

  /// The folders containing each album or subfolder, outermost first, by identifier.
  var folderPaths: [String: [AlbumGroup]] {
    let parents = parentsByChildID
    return parents.mapValues { parent in
      var path = [parent]
      while let outer = parents[path[0].identifier] { path.insert(outer, at: 0) }
      return path
    }
  }
}

extension PinnedDisplayItem {
  struct Sections {
    var pinned: [PinnedDisplayItem]
    var library: [PinnedDisplayItem]
  }

  /// Splits albums and groups into pinned and browsable-library sections, shared by every
  /// screen that lists albums: pinned albums sharing a folder collapse into it, browsable
  /// groups and albums are listed under their own folder, and search flattens both, listing
  /// every match on its own. `excluding` drops identifiers a caller already shows elsewhere
  /// (e.g. albums a photo already belongs to).
  static func sections(
    albums: [AlbumOption], groups: [AlbumGroup], pinnedIdentifiers: [String],
    search: AlbumSearchQuery, excluding: Set<String> = []
  ) -> Sections {
    let albumsByID = albums.indexed(by: \.ref.identifier)
    let identifiers = pinnedIdentifiers.filter { !excluding.contains($0) }
    let pinnedSet = Set(identifiers)
    let groupedAlbumIDs = Set(groups.flatMap(\.albumIdentifiers))
    let subgroupIDs = Set(groups.flatMap(\.groupIdentifiers))

    let pinned =
      search.isSearching
      ? identifiers.compactMap { id -> PinnedDisplayItem? in
        if let album = albumsByID[id], search.matches(album) { return .album(album) }
        return nil
      }
      : items(identifiers: identifiers, albums: albums, groups: groups)

    let libraryGroups = groups.filter {
      !pinnedSet.contains($0.identifier)
        && (search.isSearching || !subgroupIDs.contains($0.identifier))
        && search.matches($0)
    }
    let libraryAlbums = albums.filter {
      !pinnedSet.contains($0.ref.identifier) && !excluding.contains($0.ref.identifier)
        && (search.isSearching || !groupedAlbumIDs.contains($0.ref.identifier))
        && search.matches($0)
    }
    return Sections(
      pinned: pinned,
      library: libraryGroups.map(PinnedDisplayItem.folder) + libraryAlbums.map(PinnedDisplayItem.album))
  }

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
