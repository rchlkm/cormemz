// CoreMems/Views/Components/LivePhotoPlayerView.swift
import PhotosUI
import SwiftUI

/// Thin SwiftUI wrapper around `PHLivePhotoView` — SwiftUI has no
/// native Live Photo player, so this bridges UIKit's. Autoplays
/// whenever a new non-nil live photo is set, and reports when
/// playback finishes.
struct LivePhotoPlayerView: UIViewRepresentable {
  let livePhoto: PHLivePhoto?
  var onPlaybackEnded: (() -> Void)?

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> PHLivePhotoView {
    let view = PHLivePhotoView()
    view.contentMode = .scaleAspectFit
    view.delegate = context.coordinator
    return view
  }

  func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
    context.coordinator.onPlaybackEnded = onPlaybackEnded
    guard uiView.livePhoto !== livePhoto else { return }
    uiView.livePhoto = livePhoto
    guard livePhoto != nil else { return }
    // Deferred so the view is in the window hierarchy before playback starts.
    DispatchQueue.main.async { uiView.startPlayback(with: .full) }
  }

  final class Coordinator: NSObject, PHLivePhotoViewDelegate {
    var onPlaybackEnded: (() -> Void)?

    func livePhotoView(
      _ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle
    ) {
      onPlaybackEnded?()
    }
  }
}
