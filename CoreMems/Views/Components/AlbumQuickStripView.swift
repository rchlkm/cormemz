// CoreMems/Views/Components/AlbumQuickStripView.swift
import SwiftUI

/// Inline, horizontally-scrolling row of album chips shown between the
/// review card and `ReviewControlBar` while `vm.isAlbumStripExpanded` is
/// true. Chips, in order: albums the current photo is already in
/// (checked, tap removes), up to a few recently-used albums it isn't in
/// yet (unchecked, tap adds), then a trailing "More" chip that opens the
/// full `AlbumPickerView` sheet for search/creation/seeing everything.
struct AlbumQuickStripView: View {
  @ObservedObject var vm: SessionViewModel
  let photoID: String
  let onMore: () -> Void

  private static let maxSuggestions = 3

  private var allAlbums: [AlbumOption] {
    vm.userAlbums + vm.pendingNewAlbums
  }

  private var assignedRefs: Set<AlbumRef> {
    vm.effectiveAlbums(for: photoID)
  }

  private var assignedAlbums: [AlbumOption] {
    allAlbums.filter { assignedRefs.contains($0.ref) }
  }

  /// Recently-used albums the photo isn't already in, capped so the
  /// total (assigned + suggested) chip count stays small and scannable.
  private var suggestedAlbums: [AlbumOption] {
    let slotCount = max(0, Self.maxSuggestions - assignedAlbums.count)
    guard slotCount > 0 else { return [] }
    var result: [AlbumOption] = []
    for identifier in vm.recentAlbumIDs {
      guard result.count < slotCount else { break }
      guard let album = allAlbums.first(where: { $0.ref.identifier == identifier }) else {
        continue
      }
      guard !assignedRefs.contains(album.ref) else { continue }
      result.append(album)
    }
    return result
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(assignedAlbums) { album in
          chip(album, isChecked: true)
        }
        ForEach(suggestedAlbums) { album in
          chip(album, isChecked: false)
        }
        moreChip
      }
      .padding(.horizontal, 16)
    }
    .padding(.vertical, 8)
  }

  private func chip(_ album: AlbumOption, isChecked: Bool) -> some View {
    Button {
      vm.toggleAlbumMembership(photoID: photoID, ref: album.ref)
    } label: {
      HStack(spacing: 5) {
        Image(
          systemName: isChecked
            ? "checkmark.circle.fill" : (album.ref.kind == .pendingNew ? "sparkles" : "photo.stack")
        )
        .font(.system(size: 12, weight: .semibold))
        Text(album.name)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isChecked ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
      .foregroundStyle(isChecked ? .white : .primary)
    }
    .buttonStyle(.plain)
  }

  private var moreChip: some View {
    Button(action: onMore) {
      HStack(spacing: 5) {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 12, weight: .semibold))
        Text("More")
          .font(.system(size: 13, weight: .medium))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.secondary.opacity(0.15), in: Capsule())
      .foregroundStyle(.primary)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let photos = SessionViewModel.mockPhotos(count: 3)
  AlbumQuickStripView(
    vm: .mock(screen: .review, photos: photos), photoID: photos[0].id, onMore: {}
  )
  .background(Color.black)
}
