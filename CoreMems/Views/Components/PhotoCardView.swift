// CoreMems/Views/Components/PhotoCardView.swift
import SwiftUI

/// Renders a single photo at its own aspect ratio, letterboxed within
/// `maxSize` — never cropped, never padded to a fixed shape. This view
/// is intentionally dumb: no gestures, no overlays, no session state.
/// All of the browse card's chrome (date, info, add-to-album,
/// favorite/Live Photo badges, swipe handling) lives one level up in
/// `BrowseCardView`, which wraps this and sizes itself around whatever
/// this view reports back.
struct PhotoCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize

  /// Held without observing it, so only the views showing playback redraw as it plays.
  @State private var playback = VideoPlayback()

  var body: some View {
    let quarterTurns = photo.previewQuarterTurns
    if photo.isVideo {
      VideoPlayerCardView(
        playback: playback, assetIdentifier: photo.assetIdentifier, quarterTurns: quarterTurns,
        playbackRange: photo.activeEdit?.trimRange
      )
      .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
    } else {
      AdaptiveAssetImage(photo: photo, fitWithin: maxSize.turned(by: quarterTurns))
        .rotated(quarterTurns: quarterTurns)
    }
  }
}
