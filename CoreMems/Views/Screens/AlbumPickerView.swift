// CoreMems/Views/Screens/AlbumPickerView.swift
import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>

  /// The whole library, nil until loaded. Listed on search or "Show all albums".
  var libraryAlbums: [AlbumOption]? = []
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @State private var showAllAlbums = false
  @Environment(\.dismiss) private var dismiss

  private struct Results {
    var alreadyIn: [AlbumOption] = []
    var new: [AlbumOption] = []
    var existing: [AlbumOption] = []
  }

  /// One pass over `albums`, then `libraryAlbums`, so per-keystroke search stays cheap.
  /// Library albums outside `albums` are listed only when searching or after "Show all albums".
  private func computeResults(for search: AlbumSearchQuery) -> Results {
    var results = Results()

    for album in albums where search.matches(album) {
      if assignedRefs.contains(album.ref) {
        results.alreadyIn.append(album)
      } else if album.ref.kind == .pendingNew {
        results.new.append(album)
      } else {
        results.existing.append(album)
      }
    }

    if let libraryAlbums, !libraryAlbums.isEmpty {
      let loadedIDs = Set(albums.map(\.ref.identifier))
      for album in libraryAlbums where !loadedIDs.contains(album.ref.identifier) {
        guard search.matches(album) else { continue }
        if assignedRefs.contains(album.ref) {
          results.alreadyIn.append(album)
        } else if search.isSearching || showAllAlbums {
          results.existing.append(album)
        }
      }
    }

    return results
  }

  var body: some View {
    NavigationStack {
      AlbumSearchList(
        albums: albums,
        libraryAlbums: libraryAlbums,
        isLoading: libraryAlbums == nil && albums.isEmpty,
        onCreate: onCreate
      ) { search in
        let results = computeResults(for: search)

        if !results.alreadyIn.isEmpty {
          Section("Already in") {
            ForEach(results.alreadyIn) { albumRow($0) }
          }
        }

        if !results.new.isEmpty {
          Section("New albums") {
            ForEach(results.new) { albumRow($0) }
          }
        }

        if !results.existing.isEmpty {
          Section("Your Albums") {
            ForEach(results.existing) { albumRow($0) }
          }
        } else if !search.isSearching && results.alreadyIn.isEmpty && results.new.isEmpty {
          Section { AlbumSearchHint() }
        }

        if libraryAlbums != nil && !showAllAlbums && !search.isSearching {
          Section {
            Button {
              showAllAlbums = true
            } label: {
              Label("Show all albums", systemImage: "ellipsis.circle")
            }
          }
        }
      }
      .navigationTitle("Albums")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private func albumRow(_ album: AlbumOption) -> some View {
    let isAssigned = assignedRefs.contains(album.ref)
    return Button {
      onToggle(album.ref)
    } label: {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 9)
          .fill(album.ref.kind == .pendingNew ? Color.orange.gradient : Color.accentColor.gradient)
          .frame(width: 38, height: 38)
          .overlay {
            Image(systemName: album.ref.kind == .pendingNew ? "sparkles" : "photo.stack.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white)
          }

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

        if isAssigned {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.title3)
        }
      }
      .padding(.vertical, 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
