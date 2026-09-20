// CoreMems/Views/Components/PhotoGrid.swift
import SwiftUI

struct PhotoGrid: View {
  let photos: [SessionPhoto]
  let onRestore: (String) -> Void

  var body: some View {
    if !photos.isEmpty {
      ScrollView {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
          spacing: 10
        ) {
          ForEach(photos) { photo in
            ZStack(alignment: .topTrailing) {
              Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                  AdaptiveAssetImage(photo: photo, targetSize: CGSize(width: 200, height: 200))
                    .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

              Button {
                onRestore(photo.id)
              } label: {
                Image(systemName: "arrow.uturn.backward")
              }
              .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
              .padding(6)
            }
          }
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
      }
    }
  }
}
