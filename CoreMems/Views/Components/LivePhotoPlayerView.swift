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

struct LivePhotoPlaybackView: View {
  let photo: SessionPhoto

  @Environment(\.dismiss) private var dismiss
  @State private var livePhoto: PHLivePhoto?
  @State private var isLoading = true

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let livePhoto {
        LivePhotoPlayerView(livePhoto: livePhoto)
          .ignoresSafeArea()
      } else if isLoading {
        ProgressView()
          .tint(.white)
      } else {
        Text("Couldn't load Live Photo")
          .foregroundStyle(.white)
      }
    }
    .onTapGesture { dismiss() }
    .task {
      livePhoto = await LivePhotoLoader.shared.livePhoto(
        for: photo.assetIdentifier, targetSize: UIScreen.main.bounds.size)
      isLoading = false
    }
    .statusBarHidden()
  }
}
