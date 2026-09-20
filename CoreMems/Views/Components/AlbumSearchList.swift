// CoreMems/Views/Components/AlbumSearchList.swift
import SwiftUI

/// Album search text plus the shared matching rules: case- and
/// diacritic-insensitive substring match against `AlbumOption.searchKey`.
struct AlbumSearchQuery {
  let text: String

  /// `text` without surrounding whitespace; the name a create action uses.
  let trimmed: String
  private let folded: String

  init(text: String) {
    self.text = text
    self.trimmed = text.trimmingCharacters(in: .whitespaces)
    self.folded = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }

  var isSearching: Bool { !text.isEmpty }

  func matches(_ album: AlbumOption) -> Bool {
    folded.isEmpty || album.searchKey.contains(folded)
  }

  func isExactMatch(_ album: AlbumOption) -> Bool {
    !folded.isEmpty && album.searchKey == folded
  }
}

/// Explains that the search field also creates albums.
struct AlbumSearchHint: View {
  var body: some View {
    Text("Search for an album, or type a new name to create one.")
      .font(.footnote)
      .foregroundStyle(.secondary)
  }
}

/// Search-or-create list shared by the album picker and pinned albums settings.
/// Screens supply the rows via `content`; requires an enclosing `NavigationStack`.
struct AlbumSearchList<Content: View>: View {
  let albums: [AlbumOption]
  /// Every existing album, used to detect duplicate names; nil until loaded.
  let libraryAlbums: [AlbumOption]?
  /// Replaces the list with a spinner.
  let isLoading: Bool
  /// Disables the create row while a create is in flight.
  let isCreating: Bool
  let onCreate: (String) -> Void
  let content: (AlbumSearchQuery) -> Content

  @State private var searchText = ""

  init(
    albums: [AlbumOption],
    libraryAlbums: [AlbumOption]? = [],
    isLoading: Bool = false,
    isCreating: Bool = false,
    onCreate: @escaping (String) -> Void,
    @ViewBuilder content: @escaping (AlbumSearchQuery) -> Content
  ) {
    self.albums = albums
    self.libraryAlbums = libraryAlbums
    self.isLoading = isLoading
    self.isCreating = isCreating
    self.onCreate = onCreate
    self.content = content
  }

  /// A typed name is creatable when the library is known and no album has that name.
  private func canCreate(_ query: AlbumSearchQuery) -> Bool {
    guard !query.trimmed.isEmpty, let libraryAlbums else { return false }
    return !albums.contains(where: query.isExactMatch)
      && !libraryAlbums.contains(where: query.isExactMatch)
  }

  var body: some View {
    let query = AlbumSearchQuery(text: searchText)
    return List {
      if isLoading {
        HStack {
          Spacer()
          ProgressView("Loading albums…")
          Spacer()
        }
        .padding(.vertical, 24)
      } else {
        if query.isSearching {
          if libraryAlbums == nil {
            HStack {
              Spacer()
              ProgressView("Searching all albums…")
              Spacer()
            }
            .padding(.vertical, 8)
          } else if canCreate(query) {
            Section {
              Button {
                onCreate(query.trimmed)
                searchText = ""
              } label: {
                HStack {
                  Label("Create “\(query.trimmed)”", systemImage: "plus.circle.fill")
                  if isCreating {
                    Spacer()
                    ProgressView()
                  }
                }
              }
              .disabled(isCreating)
            }
          }
        }

        content(query)
      }
    }
    .searchable(
      text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search or create album"
    )
  }
}
