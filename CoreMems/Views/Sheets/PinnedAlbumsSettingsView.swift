// CoreMems/Views/Sheets/PinnedAlbumsSettingsView.swift
import SwiftUI

/// Lets the user pin the Photos albums that show first in the album picker and strip.
/// Pushed onto the Settings navigation stack.
/// The search field also creates and pins a new album (see `AlbumSearchList`).
struct PinnedAlbumsSettingsView: View {
  let albums: [AlbumOption]
  let pinnedIdentifiers: Set<String>
  let isLoading: Bool
  var isCreating: Bool = false
  var creationError: String? = nil
  let onTogglePin: (String) -> Void
  let onCreateAndPin: (String) -> Void

  /// Splits `albums` into pinned and other, keeping its order.
  private func split(for search: AlbumSearchQuery) -> (pinned: [AlbumOption], others: [AlbumOption])
  {
    var pinned: [AlbumOption] = []
    var others: [AlbumOption] = []
    for album in albums where search.matches(album) {
      if pinnedIdentifiers.contains(album.ref.identifier) {
        pinned.append(album)
      } else {
        others.append(album)
      }
    }
    return (pinned, others)
  }

  var body: some View {
    AlbumSearchList(
      albums: albums,
      isLoading: isLoading && albums.isEmpty,
      isCreating: isCreating,
      onCreate: onCreateAndPin
    ) { search in
      let (pinned, others) = split(for: search)

      if let creationError {
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
        Section("Pinned") {
          ForEach(pinned) { albumRow($0) }
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
      onTogglePin(album.ref.identifier)
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
      albums: [
        AlbumOption(ref: .existing(localIdentifier: "1"), name: "Trip 2024", assetCount: 128),
        AlbumOption(ref: .existing(localIdentifier: "2"), name: "Family", assetCount: 842),
      ],
      pinnedIdentifiers: ["1"],
      isLoading: false,
      onTogglePin: { _ in },
      onCreateAndPin: { _ in }
    )
  }
}
