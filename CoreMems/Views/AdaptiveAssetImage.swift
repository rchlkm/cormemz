import SwiftUI

/// Renders a `SessionPhoto` regardless of source:
///
/// - **Real photo** (`assetIdentifier` points to an actual `PHAsset`,
///   `previewURL` is nil): loads via `PhotoImageLoader` /
///   `PHImageManager`, sized to `targetSize` — this is what makes real
///   device photos actually show up.
/// - **Mock data** (`previewURL` set — used in Simulator/previews when
///   the library is empty or for design review): loads via
///   `AsyncImage` against the placeholder URL, same as before.
///
/// Every call site should pass a `targetSize` roughly matching its
/// on-screen point size × scale, per the §8 performance requirement —
/// don't request full-resolution images for a 46×46 tray thumbnail.
struct AdaptiveAssetImage: View {
  let photo: SessionPhoto
  var targetSize: CGSize = CGSize(width: 600, height: 800)
  var contentMode: ContentMode = .fill

  @State private var phImage: UIImage?
  @State private var loadFailed = false

  var body: some View {
    Group {
      if let phImage {
        Image(uiImage: phImage)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else if let url = photo.previewURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().aspectRatio(contentMode: contentMode)
          case .failure:
            failurePlaceholder
          default:
            loadingPlaceholder
          }
        }
      } else if loadFailed {
        failurePlaceholder
      } else {
        loadingPlaceholder
      }
    }
    .task(id: photo.assetIdentifier) {
      // Mock-data path already has a previewURL and doesn't need
      // PHImageManager at all.
      guard photo.previewURL == nil else { return }
      phImage = nil
      loadFailed = false
      let scale = UIScreen.main.scale
      let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
      let image = await PhotoImageLoader.shared.image(
        for: photo.assetIdentifier, targetSize: pixelSize)
      if let image {
        phImage = image
      } else {
        loadFailed = true
      }
    }
  }

  private var loadingPlaceholder: some View {
    ZStack {
      Color(.tertiarySystemFill)
      ProgressView()
    }
  }

  private var failurePlaceholder: some View {
    ZStack {
      Color(.tertiarySystemFill)
      Image(systemName: "photo")
        .foregroundStyle(.tertiary)
    }
  }
}
