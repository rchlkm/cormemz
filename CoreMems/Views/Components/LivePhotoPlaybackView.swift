// CoreMems/Views/Components/LivePhotoPlaybackView.swift
import PhotosUI
import SwiftUI

/// Full-screen Live Photo playback, opened from a card's Live Photo
/// badge. Fetches playback data on appear and starts it immediately;
/// tapping anywhere dismisses.
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
