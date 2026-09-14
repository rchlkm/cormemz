// CoreMems/Views/Components/LivePhotoPlayerView.swift
import PhotosUI
import SwiftUI

/// Thin SwiftUI wrapper around `PHLivePhotoView` — SwiftUI has no
/// native Live Photo player, so this bridges UIKit's. Autoplays
/// whenever a non-nil live photo is set.
struct LivePhotoPlayerView: UIViewRepresentable {
  let livePhoto: PHLivePhoto?

  func makeUIView(context: Context) -> PHLivePhotoView {
    let view = PHLivePhotoView()
    view.contentMode = .scaleAspectFit
    return view
  }

  func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
    uiView.livePhoto = livePhoto
    if livePhoto != nil {
      uiView.startPlayback(with: .full)
    }
  }
}
