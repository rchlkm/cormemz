// CoreMems/Views/Components/LivePhotoBadgeView.swift
import PhotosUI
import SwiftUI

/// Live Photo playback toggle shared by every surface that shows the badge
/// (`ReviewCardView`, `ExpandedPhotoView`). Tap plays in place; tap again reverts.
///
/// Long-press offers `onConvertToStill`, supplied by the caller.
struct LivePhotoBadgeView: View {
  let assetIdentifier: String
  let targetSize: CGSize
  @Binding var inlineLivePhoto: PHLivePhoto?
  @Binding var isShowingLivePhoto: Bool
  let onConvertToStill: () -> Void

  var body: some View {
    Button {
      if isShowingLivePhoto {
        isShowingLivePhoto = false
      } else {
        LivePhotoPlayback.start(
          assetIdentifier: assetIdentifier, targetSize: targetSize,
          inlineLivePhoto: $inlineLivePhoto, isShowingLivePhoto: $isShowingLivePhoto)
      }
    } label: {
      Image(systemName: isShowingLivePhoto ? "livephoto.slash" : "livephoto")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .contextMenu {
      Button(action: onConvertToStill) {
        Label("Convert to Still Photo", systemImage: "photo")
      }
    }
  }
}

/// Dims the photo and names the mark while it's held; swallows taps.
struct ConvertToStillOverlay: View {
  var body: some View {
    ZStack {
      Color.black.opacity(0.6)
      VStack(spacing: 8) {
        Image(systemName: "livephoto.slash")
          .font(.system(size: 34, weight: .semibold))
        Text("Marked for conversion")
          .font(.headline)
      }
      .foregroundStyle(.white)
    }
    .contentShape(Rectangle())
    .onTapGesture {}
  }
}

/// Loads a Live Photo and flips the shared playback state so the owning
/// view swaps its still image for a `LivePhotoPlayerView`.
enum LivePhotoPlayback {
  static func start(
    assetIdentifier: String,
    targetSize: CGSize,
    inlineLivePhoto: Binding<PHLivePhoto?>,
    isShowingLivePhoto: Binding<Bool>
  ) {
    Task { @MainActor in
      inlineLivePhoto.wrappedValue = await LivePhotoLoader.shared.livePhoto(
        for: assetIdentifier, targetSize: targetSize)
      isShowingLivePhoto.wrappedValue = inlineLivePhoto.wrappedValue != nil
    }
  }
}

private struct LivePhotoLongPressModifier: ViewModifier {
  let isEnabled: Bool
  let assetIdentifier: String
  let targetSize: CGSize
  @Binding var inlineLivePhoto: PHLivePhoto?
  @Binding var isShowingLivePhoto: Bool

  private static let minimumPressDuration: TimeInterval = 0.4

  func body(content: Content) -> some View {
    content.gesture(
      LongPressGesture(minimumDuration: Self.minimumPressDuration).onEnded { _ in
        LivePhotoPlayback.start(
          assetIdentifier: assetIdentifier, targetSize: targetSize,
          inlineLivePhoto: $inlineLivePhoto, isShowingLivePhoto: $isShowingLivePhoto)
      },
      including: isEnabled && !isShowingLivePhoto ? .all : .none
    )
  }
}

extension View {
  /// Press-and-hold plays the photo's Live Photo in place. No-op unless
  /// `isEnabled` or while it is already playing.
  func livePhotoLongPress(
    isEnabled: Bool,
    assetIdentifier: String,
    targetSize: CGSize,
    inlineLivePhoto: Binding<PHLivePhoto?>,
    isShowingLivePhoto: Binding<Bool>
  ) -> some View {
    modifier(
      LivePhotoLongPressModifier(
        isEnabled: isEnabled, assetIdentifier: assetIdentifier, targetSize: targetSize,
        inlineLivePhoto: inlineLivePhoto, isShowingLivePhoto: isShowingLivePhoto))
  }
}
