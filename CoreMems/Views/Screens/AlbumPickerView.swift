import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>
  var isLoading: Bool = false
  /// "Your Albums" defaults to just the pinned albums — these two drive
  /// the row that expands it to the user's whole library on request.
  var hasLoadedAllAlbums: Bool = true
  var isLoadingMoreAlbums: Bool = false
  var onLoadAllAlbums: () -> Void = {}
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var showNewAlbumAlert = false
  @State private var newAlbumName = ""
  @State private var searchText = ""

  // `albums` (existing ones, at least) arrives pre-sorted by
  // `localizedTitle` from PhotoKit — filtering preserves that order, so
  // there's no need to re-sort here.
  private var alreadyInAlbums: [AlbumOption] {
    filtered(albums.filter { assignedRefs.contains($0.ref) })
  }

  private var newAlbums: [AlbumOption] {
    filtered(albums.filter { $0.ref.kind == .pendingNew && !assignedRefs.contains($0.ref) })
  }

  private var existingAlbums: [AlbumOption] {
    filtered(albums.filter { $0.ref.kind == .existing && !assignedRefs.contains($0.ref) })
  }

  private func filtered(_ options: [AlbumOption]) -> [AlbumOption] {
    guard !searchText.isEmpty else { return options }
    return options.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  var body: some View {
    NavigationStack {
      List {
        if isLoading && albums.isEmpty {
          HStack {
            Spacer()
            ProgressView("Loading albums…")
            Spacer()
          }
          .padding(.vertical, 24)
        } else {
          Section {
            Button {
              newAlbumName = ""
              showNewAlbumAlert = true
            } label: {
              Label("New album", systemImage: "plus.circle.fill")
            }
          }

          if !alreadyInAlbums.isEmpty {
            Section("Already in") {
              ForEach(alreadyInAlbums) { albumRow($0) }
            }
          }

          if !newAlbums.isEmpty {
            Section("New albums") {
              ForEach(newAlbums) { albumRow($0) }
            }
          }

          if !existingAlbums.isEmpty {
            Section("Your Albums") {
              ForEach(existingAlbums) { albumRow($0) }
            }
          } else if !searchText.isEmpty && alreadyInAlbums.isEmpty && newAlbums.isEmpty {
            ContentUnavailableView.search(text: searchText)
          }

          if !hasLoadedAllAlbums {
            Section {
              Button {
                onLoadAllAlbums()
              } label: {
                HStack {
                  Label("Load all albums", systemImage: "ellipsis.circle")
                  if isLoadingMoreAlbums {
                    Spacer()
                    ProgressView()
                  }
                }
              }
              .disabled(isLoadingMoreAlbums)
            }
          }
        }
      }
      .navigationTitle("Albums")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(
        text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search albums"
      )
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
      .alert("New Album", isPresented: $showNewAlbumAlert) {
        TextField("Album name", text: $newAlbumName)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
          let trimmed = newAlbumName.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          onCreate(trimmed)
        }
        .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
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
