// CoreMems/Views/Sheets/PinnedAlbumsSettingsView.swift
import SwiftUI

/// Lets the user pick which real Photos albums show up by default in
/// the album picker (see `AlbumPickerView`), instead of the picker
/// showing everything or nothing. Pinning here is the same mechanism
/// that auto-pins an album CoreMems just created — and "New album"
/// here creates a real (initially empty) Photos album and pins it
/// immediately, since unlike the review picker there's no photo to
/// wait on before the album becomes real.
struct PinnedAlbumsSettingsView: View {
  let albums: [AlbumOption]
  let pinnedIdentifiers: Set<String>
  let isLoading: Bool
  var isCreating: Bool = false
  var creationError: String? = nil
  let onTogglePin: (String) -> Void
  let onCreateAndPin: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""
  @State private var showNewAlbumAlert = false
  @State private var newAlbumName = ""

  // `albums` arrives pre-sorted by `localizedTitle` from PhotoKit —
  // filtering preserves that order, so there's no need to re-sort here.
  private var pinnedAlbums: [AlbumOption] {
    filtered(albums.filter { pinnedIdentifiers.contains($0.ref.identifier) })
  }

  private var otherAlbums: [AlbumOption] {
    filtered(albums.filter { !pinnedIdentifiers.contains($0.ref.identifier) })
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
              HStack {
                Label("New album", systemImage: "plus.circle.fill")
                if isCreating {
                  Spacer()
                  ProgressView()
                }
              }
            }
            .disabled(isCreating)

            if let creationError {
              Text(creationError)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }

          Section {
            Text(
              "Pinned albums show up first when adding a photo to an album, so you can rotate through the ones you use most instead of scrolling your whole library."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }

          if !pinnedAlbums.isEmpty {
            Section("Pinned") {
              ForEach(pinnedAlbums) { album in
                albumRow(album)
              }
            }
          }

          if !otherAlbums.isEmpty {
            Section("All Albums") {
              ForEach(otherAlbums) { album in
                albumRow(album)
              }
            }
          } else if !searchText.isEmpty && pinnedAlbums.isEmpty {
            ContentUnavailableView.search(text: searchText)
          }
        }
      }
      .navigationTitle("Pinned Albums")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(
        text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search albums"
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .alert("New Album", isPresented: $showNewAlbumAlert) {
        TextField("Album name", text: $newAlbumName)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
          let trimmed = newAlbumName.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          onCreateAndPin(trimmed)
        }
        .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
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
