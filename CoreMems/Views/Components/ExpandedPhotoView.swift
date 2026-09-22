// CoreMems/Views/Components/ExpandedPhotoView.swift
import PhotosUI
import SwiftUI

/// Full-screen state of a `ReviewCardView` photo, grown into place via
/// `matchedGeometryEffect` rather than a `.fullScreenCover` modal.
/// Pinch to zoom (persists, no bounce-back), drag to pan while zoomed,
/// or drag at 1x to shrink back down into the card. Live Photos can be
/// played here too, in place of the static image.
struct ExpandedPhotoView: View {
  let photo: SessionPhoto
  @ObservedObject var vm: SessionViewModel
  var namespace: Namespace.ID
  @Binding var expandedPhoto: SessionPhoto?

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero
  @State private var dismissDrag: CGSize = .zero
  @State private var inlineLivePhoto: PHLivePhoto?
  @State private var isShowingLivePhoto = false

  private let dismissThreshold: CGFloat = 120
  private let fadeDistance: CGFloat = 400
  private let maxScale: CGFloat = 5.0
  private let doubleTapZoom: CGFloat = 2.5

  private var isZoomed: Bool { scale > 1.01 }

  var body: some View {
    let dismissDistance = hypot(dismissDrag.width, dismissDrag.height)
    let backgroundOpacity = isZoomed ? 1 : max(0, 1 - dismissDistance / fadeDistance)

    ZStack {
      Color.black
        .opacity(backgroundOpacity)
        .ignoresSafeArea()

      content
        .livePhotoLongPress(
          isEnabled: photo.isLivePhoto,
          assetIdentifier: photo.assetIdentifier,
          targetSize: UIScreen.main.bounds.size,
          inlineLivePhoto: $inlineLivePhoto,
          isShowingLivePhoto: $isShowingLivePhoto
        )
        .matchedGeometryEffect(id: photo.id, in: namespace)
        .scaleEffect(scale)
        .offset(x: panOffset.width + dismissDrag.width, y: panOffset.height + dismissDrag.height)
        .gesture(magnification)
        .simultaneousGesture(dragGesture)
        .onTapGesture(count: 2) { toggleZoom() }

      if photo.isLivePhoto {
        VStack {
          HStack {
            LivePhotoBadgeView(
              assetIdentifier: photo.assetIdentifier,
              targetSize: UIScreen.main.bounds.size,
              inlineLivePhoto: $inlineLivePhoto,
              isShowingLivePhoto: $isShowingLivePhoto,
              onConvertToStill: convertToStill,
              style: .pill
            )
            Spacer()
          }
          Spacer()
        }
        .padding(.leading, 20)
        .padding(.top, 50)
      }

      if let decision = vm.markingDecision {
        DecisionOverlay(decision: decision).transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.15), value: vm.markingDecision)
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.expandedPhoto)
  }

  @ViewBuilder
  private var content: some View {
    if isShowingLivePhoto, let inlineLivePhoto {
      LivePhotoPlayerView(
        livePhoto: inlineLivePhoto, onPlaybackEnded: { isShowingLivePhoto = false })
    } else {
      AdaptiveAssetImage(photo: photo, fitWithin: UIScreen.main.bounds.size)
    }
  }

  private var magnification: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        scale = min(max(lastScale * value, 1.0), maxScale)
      }
      .onEnded { _ in
        lastScale = scale
        if scale <= 1.05 {
          resetZoom(animated: true)
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        if isZoomed {
          panOffset = CGSize(
            width: lastPanOffset.width + value.translation.width,
            height: lastPanOffset.height + value.translation.height)
        } else {
          dismissDrag = value.translation
        }
      }
      .onEnded { value in
        if isZoomed {
          lastPanOffset = panOffset
        } else {
          let distance = hypot(value.translation.width, value.translation.height)
          if distance > dismissThreshold {
            close()
          } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
              dismissDrag = .zero
            }
          }
        }
      }
  }

  private func toggleZoom() {
    if isZoomed {
      resetZoom(animated: true)
    } else {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        scale = doubleTapZoom
        lastScale = doubleTapZoom
      }
    }
  }

  private func resetZoom(animated: Bool) {
    let apply = {
      scale = 1.0
      lastScale = 1.0
      panOffset = .zero
      lastPanOffset = .zero
    }
    if animated {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75), apply)
    } else {
      apply()
    }
  }

  /// Deciding moves the deck on, so full screen closes once the mark has shown.
  private func convertToStill() {
    guard let recording = vm.decide(index: vm.currentIndex, decision: .convertToStill) else {
      return
    }
    Task {
      await recording.value
      close()
    }
  }

  /// Mirrors the expand transition, shrinking back into the card that
  /// grew from the same `matchedGeometryEffect` id.
  private func close() {
    resetZoom(animated: false)
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      expandedPhoto = nil
    }
  }
}
