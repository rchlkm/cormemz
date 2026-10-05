// CoreMems/Views/Components/AlbumDetailsView.swift
import SwiftUI

extension EnvironmentValues {
  /// Reads what an album holds; nil when it can't be determined.
  @Entry var loadAlbumContents: (AlbumRef) async -> AlbumContents? = { _ in nil }
}

/// An album's photo and video counts and size, shown once they have been read.
struct AlbumDetailsView: View {
  let album: AlbumOption
  @Environment(\.loadAlbumContents) private var loadAlbumContents
  @Environment(\.dismiss) private var dismiss
  @State private var contents: Contents = .loading

  private enum Contents {
    case loading, loaded(AlbumContents), unavailable
  }

  var body: some View {
    NavigationStack {
      List {
        switch contents {
        case .loading:
          ProgressView()
            .frame(maxWidth: .infinity)
        case .loaded(let loaded):
          LabeledContent("Photos", value: loaded.photoCount.formatted())
          LabeledContent("Videos", value: loaded.videoCount.formatted())
          LabeledContent("Size", value: loaded.bytes?.fileSizeText ?? "Unavailable")
        case .unavailable:
          Text("Details unavailable")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle(album.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
    .task {
      contents = await loadAlbumContents(album.ref).map(Contents.loaded) ?? .unavailable
    }
  }
}
