// CoreMems/Views/Components/LivePhotoBadgeView.swift
import PhotosUI
import SwiftUI

/// Live Photo playback toggle + "Duplicate as Still Photo" action,
/// shared by every surface that shows a Live Photo badge over a photo
/// (`ReviewCardView` and `ExpandedPhotoView`). Tapping plays the Live
/// Photo in place of the static image; tapping again reverts to it.
/// Long-pressing offers converting the Live Photo to a plain still —
/// the caller supplies `onConvertToStill` to actually perform that,
/// since this view has no knowledge of the session or view model.
struct LivePhotoBadgeView: View {
  let assetIdentifier: String
  let targetSize: CGSize
  @Binding var inlineLivePhoto: PHLivePhoto?
  @Binding var isShowingLivePhoto: Bool
  let onConvertToStill: () -> Void

  @State private var isShowingConvertConfirmation = false

  var body: some View {
    Button {
      if isShowingLivePhoto {
        isShowingLivePhoto = false
      } else {
        Task {
          inlineLivePhoto = await LivePhotoLoader.shared.livePhoto(
            for: assetIdentifier, targetSize: targetSize)
          isShowingLivePhoto = inlineLivePhoto != nil
        }
      }
    } label: {
      Image(systemName: isShowingLivePhoto ? "livephoto.slash" : "livephoto")
        .font(.system(size: 18))
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.55), in: Circle())
    }
    .contextMenu {
      Button {
        isShowingConvertConfirmation = true
      } label: {
        Label("Duplicate as Still Photo", systemImage: "photo")
      }
    }
    .alert("Duplicate as Still Photo?", isPresented: $isShowingConvertConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Duplicate & Delete Original", role: .destructive, action: onConvertToStill)
    } message: {
      Text(
        "Creates a still copy with the same date, location, and favorite status, then deletes the original Live Photo (moved to Recently Deleted, recoverable there)."
      )
    }
  }
}
