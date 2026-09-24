// CoreMems/Views/Components/PinnedSectionHeader.swift
import SwiftUI

/// The "Pinned" section header, with the menu that chooses how pinned albums are ordered.
struct PinnedSectionHeader: View {
  @Binding var sort: PinnedAlbumSort

  var body: some View {
    HStack {
      Text("Pinned")
      Spacer()
      Menu {
        Picker("Sort pinned by", selection: $sort) {
          ForEach(PinnedAlbumSort.allCases) { Text($0.title).tag($0) }
        }
      } label: {
        Label(sort.title, systemImage: "arrow.up.arrow.down")
          .font(.footnote)
          .textCase(nil)
      }
    }
  }
}
