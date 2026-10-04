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
///   allowed to overflow. Use for the main browse card / full-screen view.
///
/// `still` is shown in place of the photo's own image when set.
///
/// With `showsLowQualityFirst`, a lower-quality version Photos already has is shown while the
/// full one is unavailable or loading, marked with a cloud badge in the adaptive mode.
///
/// The image is shown turned by the photo's edit, or by `quarterTurns` when set. Sizes are
/// given for the turned image.
struct AdaptiveAssetImage: View {
  let photo: SessionPhoto
  var targetSize: CGSize = CGSize(width: 600, height: 800)
  var contentMode: ContentMode = .fill
  var fitWithin: CGSize? = nil
  var quarterTurns: Int? = nil
  var still: UIImage? = nil
  var showsLowQualityFirst = false

  @State private var phImage: UIImage?
  @State private var isLowQuality = false
  @State private var loadFailed = false

  private var turns: Int { quarterTurns ?? photo.previewQuarterTurns }

  var body: some View {
    image.rotated(quarterTurns: turns)
      .overlay(alignment: .bottomTrailing) {
        if isLowQuality { LowQualityBadge().padding(Self.badgePadding) }
      }
  }

  private static let badgePadding: CGFloat = 8

  private var image: some View {
    Group {
      if let shown = still ?? phImage {
        Image(uiImage: shown)
          .resizable()
          .aspectRatio(contentMode: fitWithin != nil ? .fit : contentMode)
      } else if let url = photo.previewURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().aspectRatio(contentMode: fitWithin != nil ? .fit : contentMode)
          case .failure:
            AssetPlaceholderView(state: .failed(icon: "photo"))
          default:
            AssetPlaceholderView(state: .loading)
          }
        }
      } else if loadFailed {
        // An asset that can't load is assumed to be in iCloud, out of reach right now.
        AssetPlaceholderView(state: .failed(icon: "icloud.slash"))
      } else {
        AssetPlaceholderView(state: .loading)
      }
    }
    .modifier(SizingModifier(fitWithin: fitWithin?.turned(by: turns), targetSize: targetSize.turned(by: turns)))
    .task(id: photo.assetIdentifier) {
      guard photo.previewURL == nil else { return }
      phImage = nil
      isLowQuality = false
      loadFailed = false
      let scale = UIScreen.main.scale
      // Request at whichever bounding box actually applies, so we're
      // never pulling a full-res original for a small view.
      let requestSize = fitWithin?.turned(by: turns) ?? targetSize.turned(by: turns)
      let pixelSize = CGSize(width: requestSize.width * scale, height: requestSize.height * scale)
      if showsLowQualityFirst {
        let loads = await PhotoImageLoader.shared.progressiveImages(
          for: photo.assetIdentifier, targetSize: pixelSize)
        for await loaded in loads {
          phImage = loaded.image
          isLowQuality = loaded.isDegraded
        }
        loadFailed = phImage == nil
      } else if let image = await PhotoImageLoader.shared.image(
        for: photo.assetIdentifier, targetSize: pixelSize)
      {
        phImage = image
      } else {
        loadFailed = true
      }
    }
  }
}

/// Cloud badge on an image that is a lower-quality stand-in for the full one.
private struct LowQualityBadge: View {
  var body: some View {
    Image(systemName: "icloud")
      .font(.system(size: 10, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 20, height: 20)
      .background(.black.opacity(0.6), in: Circle())
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
