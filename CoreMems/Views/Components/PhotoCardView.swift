// CoreMems/Views/Components/PhotoCardView.swift
import PhotosUI
import SwiftUI

/// Renders one photo, video or playing Live Photo at its own aspect ratio, letterboxed
/// within `maxSize` — never cropped, never padded to a fixed shape. It has no gestures,
/// overlays or session state; callers supply the turn, trim range and playback to show.
/// The browse card passes the saved edit's values and the full-screen editor the draft's.
struct PhotoCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize
  let quarterTurns: Int
  let playbackRange: ClosedRange<Double>?
  /// Held by the caller so controls outside the player, such as the trim bar, can drive it.
  let playback: VideoPlayback
  /// Off when other controls stand in for the video's transport bar.
  var showsTransport = true
  /// The Live Photo to play in place of the still; `nil` shows the still.
  var livePhoto: PHLivePhoto?
  var onLivePhotoEnded: () -> Void = {}

  var body: some View {
    if let livePhoto {
      LivePhotoPlayerView(livePhoto: livePhoto, onPlaybackEnded: onLivePhotoEnded)
        .aspectRatio(livePhoto.size, contentMode: .fit)
        .rotated(quarterTurns: quarterTurns)
        .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
    } else if photo.isVideo {
      VideoPlayerView(
        playback: playback, assetIdentifier: photo.assetIdentifier, quarterTurns: quarterTurns,
        playbackRange: playbackRange, showsTransport: showsTransport
      )
      .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
    } else {
      AdaptiveAssetImage(photo: photo, fitWithin: maxSize, quarterTurns: quarterTurns)
    }
  }
}
