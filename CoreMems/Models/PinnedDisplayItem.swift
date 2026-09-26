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
}
