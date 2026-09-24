// CoreMems/Views/Components/AlbumQuickStripView.swift
import SwiftUI

/// Album chips under the review card: a fixed "More" chip, then the photo's albums
/// (checked), pinned, and recent ones.
struct AlbumQuickStripView: View {
  @ObservedObject var vm: SessionViewModel
  let photoID: String
  let onMore: () -> Void

  /// Chips held after the first tap on a photo, so tapped chips stay put and unchecked ones stay visible.
  @State private var heldAlbums: [AlbumOption]?

  private struct Chip {
    let album: AlbumOption
    let isChecked: Bool
  }

  private var allAlbums: [AlbumOption] {
    vm.quickAccessAlbums + vm.pendingNewAlbums
  }

  private var assignedRefs: Set<AlbumRef> {
    vm.effectiveAlbums(for: photoID)
  }

  /// Resolved against the whole library, so unpinned albums still appear.
  private var assignedAlbums: [AlbumOption] {
    let assigned = assignedRefs
    return (vm.libraryAlbums ?? []).filter { assigned.contains($0.ref) }
      + vm.pendingNewAlbums.filter { assigned.contains($0.ref) }
  }

  private var pinnedAlbums: [AlbumOption] {
    let assigned = assignedRefs
    return allAlbums.filter {
      vm.pinnedAlbums.identifiers.contains($0.ref.identifier) && !assigned.contains($0.ref)
    }
  }

  /// Recents missing from the library are skipped.
  private var recentAlbums: [AlbumOption] {
    let all = allAlbums
    let assigned = assignedRefs
    var result: [AlbumOption] = []
    for identifier in vm.recentAlbumIDs {
      guard !vm.pinnedAlbums.identifiers.contains(identifier) else { continue }
      guard let album = all.first(where: { $0.ref.identifier == identifier }) else {
        continue
      }
      guard !assigned.contains(album.ref) else { continue }
      result.append(album)
    }
    return result
  }

  private var chips: [Chip] {
    let natural =
      assignedAlbums.map { Chip(album: $0, isChecked: true) }
      + (pinnedAlbums + recentAlbums).map { Chip(album: $0, isChecked: false) }
    guard let heldAlbums else { return natural }
    let heldRefs = Set(heldAlbums.map(\.ref))
    let assigned = assignedRefs
    return heldAlbums.map { Chip(album: $0, isChecked: assigned.contains($0.ref)) }
      + natural.filter { !heldRefs.contains($0.album.ref) }
  }

  var body: some View {
    HStack(spacing: 8) {
      moreChip
        .padding(.leading, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(chips, id: \.album.id) { chip in
            chipButton(chip.album, isChecked: chip.isChecked)
          }
        }
        .padding(.trailing, 16)
      }
    }
    .padding(.vertical, 8)
    .onChange(of: photoID) { heldAlbums = nil }
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

  private func holdChips() {
    if heldAlbums == nil { heldAlbums = chips.map(\.album) }
  }

  private var moreChip: some View {
    Button {
      heldAlbums = nil
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
