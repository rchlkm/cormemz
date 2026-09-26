// CoreMems/Views/Components/AlbumQuickStripView.swift
import SwiftUI

/// Album chips under the review card: a fixed "More" chip, then the photo's albums
/// (checked), pinned, and recent ones.
struct AlbumQuickStripView: View {
  @ObservedObject var vm: SessionViewModel
  let photoID: String
  let onMore: () -> Void

  /// Entries held after the first tap on a photo, so tapped chips stay put and unchecked ones stay visible.
  @State private var heldEntries: [Entry]?

  private struct Chip {
    let album: AlbumOption
    let isChecked: Bool
  }

  private enum Entry: Identifiable {
    case chip(Chip)
    case folder(PinnedDisplayItem)

    var id: String {
      switch self {
      case .chip(let chip): return chip.album.ref.identifier
      case .folder(let item): return item.id
      }
    }
  }

  /// The strip's entries for the photo, deriving each lookup once; `assigned` is the photo's
  /// albums. Pinned albums and folders share one order, so folders can sit anywhere among them.
  private func makeEntries(assigned: Set<AlbumRef>) -> [Entry] {
    let items = vm.pinnedDisplayItems
    let all = vm.quickAccessAlbums + vm.pendingNewAlbums
    let pinnedIDs = Set(vm.pinnedAlbums.identifiers)
    let allByID = all.indexed(by: \.ref.identifier)

    // Albums inside a folder chip are counted on it instead of getting a checked chip.
    let folderAlbumIDs = Set(
      items.flatMap { item -> [String] in
        guard case .collapsedFolder(let group, _) = item else { return [] }
        return group.albumIdentifiers
      })
    // Resolved against the whole library, so unpinned albums still appear.
    let assignedAlbums =
      (vm.libraryAlbums ?? []).filter {
        assigned.contains($0.ref) && !folderAlbumIDs.contains($0.ref.identifier)
      } + vm.pendingNewAlbums.filter { assigned.contains($0.ref) }
    let pinned = items.compactMap { item -> Entry? in
      guard case .album(let album) = item else { return .folder(item) }
      return assigned.contains(album.ref) ? nil : .chip(Chip(album: album, isChecked: false))
    }
    // Recents missing from the library are skipped.
    let recents = vm.recentAlbumIDs.compactMap { identifier -> Entry? in
      guard !pinnedIDs.contains(identifier), let album = allByID[identifier],
        !assigned.contains(album.ref)
      else { return nil }
      return .chip(Chip(album: album, isChecked: false))
    }

    let natural =
      assignedAlbums.map { Entry.chip(Chip(album: $0, isChecked: true)) } + pinned + recents
    guard let heldEntries else { return natural }
    let heldIDs = Set(heldEntries.map(\.id))
    let held = heldEntries.map { entry -> Entry in
      guard case .chip(let chip) = entry else { return entry }
      return .chip(Chip(album: chip.album, isChecked: assigned.contains(chip.album.ref)))
    }
    return held + natural.filter { !heldIDs.contains($0.id) }
  }

  var body: some View {
    let assigned = vm.effectiveAlbums(for: photoID)
    let entries = makeEntries(assigned: assigned)
    return HStack(spacing: 8) {
      moreChip
        .padding(.leading, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(entries) { entry in
            switch entry {
            case .chip(let chip): chipButton(chip.album, isChecked: chip.isChecked)
            case .folder(let item): folderChip(item, assigned: assigned)
            }
          }
        }
        .padding(.trailing, 16)
      }
    }
    .padding(.vertical, 8)
    .onChange(of: photoID) { heldEntries = nil }
  }

  private func chipIcon(_ album: AlbumOption, isChecked: Bool) -> String {
    if isChecked { return "checkmark.circle.fill" }
    if album.ref.kind == .pendingNew { return "sparkles" }
    let isPinned = vm.pinnedAlbums.identifiers.contains(album.ref.identifier)
    return isPinned ? "pin.fill" : "clock.arrow.circlepath"
  }

  private func chipButton(_ album: AlbumOption, isChecked: Bool) -> some View {
    Button {
      holdChips()
      vm.toggleAlbumMembership(photoID: photoID, ref: album.ref)
    } label: {
      HStack(spacing: 5) {
        Image(systemName: chipIcon(album, isChecked: isChecked))
        Text(album.name)
          .lineLimit(1)
      }
    }
    .buttonStyle(ChipButtonStyle(isSelected: isChecked))
    .contextMenu {
      if album.ref.kind == .existing {
        AlbumPinButton(isPinned: vm.pinnedAlbums.identifiers.contains(album.ref.identifier)) {
          holdChips()
          vm.pinnedAlbums.toggle(album.ref.identifier)
        }
      }
    }
  }

  /// Opens a menu of the folder's pinned albums and any other album of the folder the photo is in.
  /// Highlighted, with a count badge, while the photo is in any of them.
  @ViewBuilder
  private func folderChip(_ item: PinnedDisplayItem, assigned: Set<AlbumRef>) -> some View {
    switch item {
    case .album, .folder:
      EmptyView()
    case .collapsedFolder(let group, let pinned):
      let inGroup = Set(group.albumIdentifiers)
      let listed = Set(pinned.map(\.ref))
      let albums =
        pinned
        + (vm.libraryAlbums ?? []).filter {
          inGroup.contains($0.ref.identifier) && assigned.contains($0.ref)
            && !listed.contains($0.ref)
        }
      folderChip(name: group.name, albums: albums, assigned: assigned) {
        albumButtons(albums, assigned: assigned)
      }
    }
  }

  private func folderChip<MenuContent: View>(
    name: String, albums: [AlbumOption], assigned: Set<AlbumRef>,
    @ViewBuilder menu: () -> MenuContent
  ) -> some View {
    let assignedCount = albums.filter { assigned.contains($0.ref) }.count
    return Menu {
      menu()
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "folder.fill")
        Text(name)
          .lineLimit(1)
        if assignedCount > 0 {
          Text("\(assignedCount)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.3), in: Capsule())
        }
      }
    }
    .buttonStyle(ChipButtonStyle(isSelected: assignedCount > 0))
  }

  private func albumButtons(_ albums: [AlbumOption], assigned: Set<AlbumRef>) -> some View {
    ForEach(albums) { album in
      Button {
        holdChips()
        vm.toggleAlbumMembership(photoID: photoID, ref: album.ref)
      } label: {
        if assigned.contains(album.ref) {
          Label(album.name, systemImage: "checkmark")
        } else {
          Text(album.name)
        }
      }
    }
  }

  private func holdChips() {
    if heldEntries == nil {
      heldEntries = makeEntries(assigned: vm.effectiveAlbums(for: photoID))
    }
  }

  private var moreChip: some View {
    Button {
      heldEntries = nil
      onMore()
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "ellipsis.circle")
        Text("More")
      }
    }
    .buttonStyle(ChipButtonStyle())
  }
}

#Preview {
  let photos = SessionViewModel.mockPhotos(count: 3)
  AlbumQuickStripView(
    vm: .mock(screen: .review, photos: photos), photoID: photos[0].id, onMore: {}
  )
  .background(Color.black)
}
