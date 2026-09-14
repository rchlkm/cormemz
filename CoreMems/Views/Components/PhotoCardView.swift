// CoreMems/Views/Components/PhotoCardView.swift
import SwiftUI

/// Renders a single photo at its own aspect ratio, letterboxed within
/// `maxSize` — never cropped, never padded to a fixed shape. This view
/// is intentionally dumb: no gestures, no overlays, no session state.
/// All of the review card's chrome (date, info, add-to-album,
/// favorite/Live Photo badges, swipe handling) lives one level up in
/// `ReviewCardView`, which wraps this and sizes itself around whatever
/// this view reports back.
struct PhotoCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize

  var body: some View {
    AdaptiveAssetImage(photo: photo, fitWithin: maxSize)
  }
}
