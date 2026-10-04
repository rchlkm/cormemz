// CoreMems/Views/Components/PhotoCardView.swift
import PhotosUI
import SwiftUI

/// Renders one photo, video or playing Live Photo at its own aspect ratio, letterboxed
/// within `maxSize` — never cropped, never padded to a fixed shape. It has no gestures,
/// overlays or session state; it shows the photo's saved edit, or `draftEdit` when set.
struct PhotoCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize
  /// Held by the caller so controls outside the player, such as the trim bar, can drive it.
  let playback: VideoPlayback
  /// The edit being made, shown in place of the photo's saved one.
  var draftEdit: MediaEdit?
  /// Off when other controls stand in for the video's transport bar.
  var showsTransport = true
  /// The Live Photo to play in place of the still; `nil` shows the still.
  var livePhoto: PHLivePhoto?
  var onLivePhotoEnded: () -> Void = {}
  /// Shown in place of a photo's or Live Photo's still, such as a Live Photo frame.
  var still: UIImage?

  private var shownEdit: MediaEdit? { draftEdit ?? photo.activeEdit }
  private var quarterTurns: Int { shownEdit?.quarterTurns ?? 0 }

  var body: some View {
    if photo.isVideo && livePhoto == nil {
      // The player turns only its picture, so its controls stay upright.
      VideoPlayerView(
        playback: playback, assetIdentifier: photo.assetIdentifier, quarterTurns: quarterTurns,
        playbackRange: shownEdit?.trimRange, showsTransport: showsTransport
      )
      .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
    } else {
      picture
        .rotated(quarterTurns: quarterTurns)
        .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
    }
  }

  @ViewBuilder private var picture: some View {
    if let livePhoto {
      LivePhotoPlayerView(livePhoto: livePhoto, onPlaybackEnded: onLivePhotoEnded)
        .aspectRatio(livePhoto.size, contentMode: .fit)
    } else {
      AdaptiveAssetImage(
        photo: photo, fitWithin: maxSize.turned(by: quarterTurns), quarterTurns: 0, still: still)
    }
  }
}
