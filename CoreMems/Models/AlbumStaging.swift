// CoreMems/Models/AlbumStaging.swift
import Foundation

/// Album changes staged during a session and applied to the library on confirmation.
struct AlbumStaging {
  private var initialMembership: [String: Set<String>] = [:]  // photoID -> album IDs at load
  private(set) var additions: [String: Set<AlbumRef>] = [:]
  private(set) var removals: [String: Set<String>] = [:]  // photoID -> existing album IDs
  /// Created this session, not yet in the library; stay pickable for every photo.
  private(set) var pendingNewAlbums: [AlbumOption] = []

  init() {}

  init(
    additions: [String: Set<AlbumRef>], removals: [String: Set<String>],
    pendingNewAlbums: [AlbumOption]
  ) {
    self.additions = additions
    self.removals = removals
    self.pendingNewAlbums = pendingNewAlbums
    refreshPendingAlbumCounts()
  }

  func hasInitialMembership(for photoID: String) -> Bool {
    initialMembership[photoID] != nil
  }

  mutating func setInitialMembership(_ albumIDs: Set<String>, for photoID: String) {
    initialMembership[photoID] = albumIDs
  }

  /// The library's starting membership merged with the staged additions and removals.
  func effectiveAlbums(for photoID: String) -> Set<AlbumRef> {
    var result = Set((initialMembership[photoID] ?? []).map(AlbumRef.existing))
    if let removed = removals[photoID] {
      result.subtract(removed.map(AlbumRef.existing))
    }
    if let added = additions[photoID] {
      result.formUnion(added)
    }
    return result
  }

  /// Toggles `ref` for `photoID` and returns whether the photo is now in it. Toggling an
  /// album the photo started in (then back) leaves nothing staged.
  @discardableResult
  mutating func toggle(photoID: String, ref: AlbumRef) -> Bool {
    let wasInitialMember =
      ref.kind == .existing && (initialMembership[photoID]?.contains(ref.identifier) ?? false)
    let isMember = effectiveAlbums(for: photoID).contains(ref)

    if isMember {
      // Also drops an add staged before membership loaded.
      if additions[photoID]?.remove(ref) != nil {
        adjustPendingCount(of: ref, by: -1)
      }
      if additions[photoID]?.isEmpty == true {
        additions.removeValue(forKey: photoID)
      }
      if wasInitialMember {
        removals[photoID, default: []].insert(ref.identifier)
      }
    } else if wasInitialMember {
      removals[photoID]?.remove(ref.identifier)
      if removals[photoID]?.isEmpty == true {
        removals.removeValue(forKey: photoID)
      }
    } else {
      additions[photoID, default: []].insert(ref)
      adjustPendingCount(of: ref, by: 1)
    }
    return !isMember
  }

  /// Adds a not-yet-real album, optionally staging it onto one photo.
  mutating func createPendingAlbum(name: String, assignTo photoID: String?) {
    let ref = AlbumRef.pendingNew(tempID: UUID().uuidString, name: name)
    pendingNewAlbums.append(AlbumOption(ref: ref, name: name, assetCount: 0))
    if let photoID {
      additions[photoID, default: []].insert(ref)
      adjustPendingCount(of: ref, by: 1)
    }
  }

  /// The staged changes minus those on photos that are being deleted.
  func changes(excludingPhotoIDs excluded: Set<String>) -> (
    additions: [String: Set<AlbumRef>], removals: [String: Set<String>]
  ) {
    (additions.filter { !excluded.contains($0.key) }, removals.filter { !excluded.contains($0.key) })
  }

  /// Drops everything staged; the library's starting membership stays.
  mutating func clearStaged() {
    additions = [:]
    removals = [:]
    pendingNewAlbums = []
  }

  private mutating func adjustPendingCount(of ref: AlbumRef, by delta: Int) {
    guard let i = pendingNewAlbums.firstIndex(where: { $0.ref == ref }) else { return }
    pendingNewAlbums[i].assetCount = (pendingNewAlbums[i].assetCount ?? 0) + delta
  }

  private mutating func refreshPendingAlbumCounts() {
    for i in pendingNewAlbums.indices {
      let ref = pendingNewAlbums[i].ref
      pendingNewAlbums[i].assetCount = additions.values.filter { $0.contains(ref) }.count
    }
  }
}
