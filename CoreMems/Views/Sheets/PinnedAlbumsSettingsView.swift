// CoreMems/Views/Sheets/PinnedAlbumsSettingsView.swift
import SwiftUI

/// Lets the user pin the Photos albums that show first in the album picker and strip,
/// and order them by hand or by recent use.
/// Pushed onto the Settings navigation stack.
/// The search field also creates and pins a new album (see `AlbumSearchList`).
struct PinnedAlbumsSettingsView: View {
  @ObservedObject var pinnedAlbums: PinnedAlbumsViewModel
  /// The pinned album IDs in display order.
  let pinnedIdentifiers: [String]

  /// Pinned albums in pin order, and the rest in `albums` order.
  private func split(for search: AlbumSearchQuery) -> (pinned: [AlbumOption], others: [AlbumOption])
  {
    let albums = pinnedAlbums.albums
    let albumsByID = Dictionary(
      albums.map { ($0.ref.identifier, $0) }, uniquingKeysWith: { first, _ in first })
    let pinned = pinnedIdentifiers.compactMap { albumsByID[$0] }.filter(search.matches)
    let others = albums.filter {
      !pinnedIdentifiers.contains($0.ref.identifier) && search.matches($0)
    }
    return (pinned, others)
  }

  var body: some View {
    AlbumSearchList(
      albums: pinnedAlbums.albums,
      isLoading: pinnedAlbums.isLoading && pinnedAlbums.albums.isEmpty,
      isCreating: pinnedAlbums.isCreating,
      onCreate: { pinnedAlbums.createAndPin(name: $0) }
    ) { search in
      let (pinned, others) = split(for: search)

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
            "Pinned albums show up first when adding a photo to an album, so you can rotate through the ones you use most instead of scrolling your whole library."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }

      if !pinned.isEmpty {
        Section {
          ForEach(pinned) { albumRow($0) }
            .reorderable(
              pinnedAlbums.sort == .myOrder && !search.isSearching,
              ids: pinned.map(\.ref.identifier), onReorder: { pinnedAlbums.reorder($0) })
        } header: {
          PinnedSectionHeader(sort: $pinnedAlbums.sort)
        }
      }

      if !others.isEmpty {
        Section("All Albums") {
          ForEach(others) { albumRow($0) }
        }
      } else if !search.isSearching && pinned.isEmpty {
        Section { AlbumSearchHint() }
      }
    }
    .navigationTitle("Pinned Albums")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func albumRow(_ album: AlbumOption) -> some View {
    let isPinned = pinnedIdentifiers.contains(album.ref.identifier)
    return Button {
      pinnedAlbums.toggle(album.ref.identifier)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isPinned ? "pin.fill" : "pin")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isPinned ? Color.accentColor : .secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 1) {
          Text(album.name)
            .foregroundStyle(.primary)
          if let count = album.assetCount {
            Text("\(count) photo\(count == 1 ? "" : "s")")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()
      }
      .padding(.vertical, 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
        pinned: ["1"]),
      pinnedIdentifiers: ["1"]
    )
  }
}
