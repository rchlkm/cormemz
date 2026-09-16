import SwiftUI

struct AlbumPickerView: View {
  let albums: [AlbumOption]
  let assignedRefs: Set<AlbumRef>
  let onToggle: (AlbumRef) -> Void
  let onCreate: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var creating = false
  @State private var name = ""
  @State private var searchText = ""

  private var alreadyInAlbums: [AlbumOption] {
    filtered(albums.filter { assignedRefs.contains($0.ref) })
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var newAlbums: [AlbumOption] {
    filtered(albums.filter { $0.ref.kind == .pendingNew && !assignedRefs.contains($0.ref) })
  }

  private var existingAlbums: [AlbumOption] {
    filtered(albums.filter { $0.ref.kind == .existing && !assignedRefs.contains($0.ref) })
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private func filtered(_ options: [AlbumOption]) -> [AlbumOption] {
    guard !searchText.isEmpty else { return options }
    return options.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  var body: some View {
    NavigationStack {
      List {
        if !creating {
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

          Section {
            Button {
              creating = true
            } label: {
              Label("New album", systemImage: "plus.circle.fill")
            }
          }
        } else {
          Section {
            TextField("Album name", text: $name)
          }

          Section {
            Button("Create album") {
              guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
              onCreate(name)
              name = ""
              creating = false
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
      }
      .navigationTitle("Add to album")
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
