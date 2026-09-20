// CoreMems/Views/Components/AlbumQuickStripView.swift
import SwiftUI

/// Album chips under the review card: a fixed "More" chip, then the photo's albums
/// (checked), pinned, and recent ones.
struct AlbumQuickStripView: View {
  @ObservedObject var vm: SessionViewModel
  let photoID: String
  let onMore: () -> Void

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
      vm.pinnedAlbumIdentifiers.contains($0.ref.identifier) && !assigned.contains($0.ref)
    }
  }

  /// Recents missing from the library are skipped.
  private var recentAlbums: [AlbumOption] {
    let all = allAlbums
    let assigned = assignedRefs
    var result: [AlbumOption] = []
    for identifier in vm.recentAlbumIDs {
      guard !vm.pinnedAlbumIdentifiers.contains(identifier) else { continue }
      guard let album = all.first(where: { $0.ref.identifier == identifier }) else {
        continue
      }
      guard !assigned.contains(album.ref) else { continue }
      result.append(album)
    }
    return result
  }

  var body: some View {
    HStack(spacing: 8) {
      moreChip
        .padding(.leading, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(assignedAlbums) { album in
            chip(album, isChecked: true)
          }
          ForEach(pinnedAlbums) { album in
            chip(album, isChecked: false)
          }
          ForEach(recentAlbums) { album in
            chip(album, isChecked: false)
          }
        }
        .padding(.trailing, 16)
      }
    }
    .padding(.vertical, 8)
  }

  private func chipIcon(_ album: AlbumOption, isChecked: Bool) -> String {
    if isChecked { return "checkmark.circle.fill" }
    return album.ref.kind == .pendingNew ? "sparkles" : "pin.fill"
  }

  private func chip(_ album: AlbumOption, isChecked: Bool) -> some View {
    Button {
      vm.toggleAlbumMembership(photoID: photoID, ref: album.ref)
    } label: {
      HStack(spacing: 5) {
        Image(systemName: chipIcon(album, isChecked: isChecked))
        Text(album.name)
          .lineLimit(1)
      }
    }
    .buttonStyle(ChipButtonStyle(isSelected: isChecked))
  }

  private var moreChip: some View {
    Button(action: onMore) {
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
