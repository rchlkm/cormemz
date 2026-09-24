// CoreMems/Views/Components/AdaptiveAssetImage.swift
import SwiftUI

/// Renders a `SessionPhoto` regardless of source.
///
/// Two sizing modes:
/// - **Fixed/cropped** (`fitWithin == nil`, default): exact `targetSize`,
///   clipped. Use for thumbnails and grids that need a consistent shape.
/// - **Adaptive/uncropped** (`fitWithin` set): aspect-fits the *whole*
///   photo inside that box — landscape photos go wide (capped by
///   `fitWithin.width`), portrait photos go tall (capped by
///   `fitWithin.height`) — whichever limit is hit first wins, and the
///   view's own size shrinks to match. Nothing is ever cropped or
///   allowed to overflow. Use for the main review card / full-screen view.
struct AdaptiveAssetImage: View {
  let photo: SessionPhoto
  var targetSize: CGSize = CGSize(width: 600, height: 800)
  var contentMode: ContentMode = .fill
  var fitWithin: CGSize? = nil

  @State private var phImage: UIImage?
  @State private var loadFailed = false

  var body: some View {
    Group {
      if let phImage {
        Image(uiImage: phImage)
          .resizable()
          .aspectRatio(contentMode: fitWithin != nil ? .fit : contentMode)
      } else if let url = photo.previewURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().aspectRatio(contentMode: fitWithin != nil ? .fit : contentMode)
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
    .modifier(SizingModifier(fitWithin: fitWithin, targetSize: targetSize))
    .task(id: photo.assetIdentifier) {
      guard photo.previewURL == nil else { return }
      phImage = nil
      loadFailed = false
      let scale = UIScreen.main.scale
      // Request at whichever bounding box actually applies, so we're
      // never pulling a full-res original for a small view.
      let requestSize = fitWithin ?? targetSize
      let pixelSize = CGSize(width: requestSize.width * scale, height: requestSize.height * scale)
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

/// Fixed mode: exact frame + clip (thumbnails/grids).
/// Adaptive mode: capped max size, no forced minimum — lets the view
/// take on the photo's real aspect ratio instead of stretching/cropping.
private struct SizingModifier: ViewModifier {
  let fitWithin: CGSize?
  let targetSize: CGSize

  func body(content: Content) -> some View {
    if let box = fitWithin {
      content.frame(maxWidth: box.width, maxHeight: box.height)
    } else {
      content.frame(width: targetSize.width, height: targetSize.height).clipped()
    }
  }
}
