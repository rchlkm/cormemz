// CoreMems/Views/Components/ReviewCardView.swift
import PhotosUI
import SwiftUI

/// Interactive review card: swipe-to-decide gestures, pinch zoom, and
/// all card chrome (date, info and Live Photo badges). `PhotoCardView`
/// underneath only renders the photo.
///
/// Expanding to full screen is a `matchedGeometryEffect` hand-off to
/// `ExpandedPhotoView`, not a `.fullScreenCover` — the photo grows into
/// full screen instead of a modal sliding up.
struct ReviewCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize
  @ObservedObject var vm: SessionViewModel
  var namespace: Namespace.ID
  @Binding var expandedPhoto: SessionPhoto?

  @State private var dragOffset: CGSize = .zero
  @State private var lastDragTranslation: CGSize = .zero
  @State private var zoomScale: CGFloat = 1.0
  @State private var showMetadata = false
  @State private var inlineLivePhoto: PHLivePhoto?
  @State private var isShowingLivePhoto = false

  /// Pinch scale past which the card hands off to full screen instead
  /// of bouncing back.
  private let fullScreenZoomThreshold: CGFloat = 1.6

  private var isExpanded: Bool { expandedPhoto?.id == photo.id }

  private var livePhotoTargetSize: CGSize {
    CGSize(width: maxSize.width * 2, height: maxSize.height * 2)
  }

  var body: some View {
    // ExpandedPhotoView shares this card's matchedGeometryEffect id,
    // so while expanded this spot renders nothing and the photo
    // appears to grow out of it instead.
    Group {
      if !isExpanded {
        swipableCard
      }
    }
  }

  /// What a drag in progress would do on release, and how far along it is (0...1).
  private var draggedOverlay: (overlay: DecisionOverlay, progress: Double)? {
    let dx = dragOffset.width
    let dy = dragOffset.height
    if dx > 0 && (dx >= abs(dy) || dx > 90) {
      return (DecisionOverlay(decision: .keep), min(1, dx / 90))
    }
    if dy > 0 && abs(dy) > abs(dx) {
      return (DecisionOverlay(decision: .pendingDelete), min(1, dy / 90))
    }
    if vm.canUndo && dx < 0 && abs(dx) > abs(dy) {
      return (.undo, min(1, -dx / 90))
    }
    return nil
  }

  /// The swipe-up hint sits behind the photo, fixed in place, so dragging the
  /// photo upward opens a gap at its bottom edge that reveals the hint
  /// underneath — the hint itself never moves with the drag.
  private var swipableCard: some View {
    ZStack {
      swipeUpHint
      cardForeground
    }
  }

  private var cardForeground: some View {
    Group {
      if isShowingLivePhoto, let inlineLivePhoto {
        LivePhotoPlayerView(
          livePhoto: inlineLivePhoto, onPlaybackEnded: { isShowingLivePhoto = false }
        )
        .aspectRatio(inlineLivePhoto.size, contentMode: .fit)
        .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
      } else {
        PhotoCardView(photo: photo, maxSize: maxSize)
          .matchedGeometryEffect(id: photo.id, in: namespace)
      }
    }
    .livePhotoLongPress(
      isEnabled: photo.isLivePhoto,
      assetIdentifier: photo.assetIdentifier,
      targetSize: livePhotoTargetSize,
      inlineLivePhoto: $inlineLivePhoto,
      isShowingLivePhoto: $isShowingLivePhoto
    )
    .scaleEffect(zoomScale)
    .gesture(pinchToZoom)
    .overlay(alignment: .top) { topBar }
    .overlay(alignment: .bottomLeading) {
      if photo.isLivePhoto {
        LivePhotoBadgeView(
          assetIdentifier: photo.assetIdentifier,
          targetSize: livePhotoTargetSize,
          inlineLivePhoto: $inlineLivePhoto,
          isShowingLivePhoto: $isShowingLivePhoto,
          onConvertToStill: { vm.decide(index: vm.currentIndex, decision: .convertToStill) }
        )
        .accessibilityIdentifier(AccessibilityID.liveBadge)
      }
    }
    .overlay(alignment: .bottom) {
      if photo.decision == .convertToStill {
        conversionMarker
      }
    }
    .overlay(alignment: .bottomTrailing) {
      infoBadge
    }
    .overlay {
      if let decision = vm.markingDecision {
        DecisionOverlay(decision: decision).transition(.opacity)
      } else if let dragged = draggedOverlay {
        dragged.overlay
          .opacity(dragged.progress)
          .allowsHitTesting(false)
      }
    }
    .animation(.easeOut(duration: 0.15), value: vm.markingDecision)
    .clipShape(RoundedRectangle(cornerRadius: 26))
    .contentShape(RoundedRectangle(cornerRadius: 26))
    .onTapGesture { expand() }
    .simultaneousGesture(dragGesture)  // A plain gesture is blocked by the pinch above.
    .offset(dragOffset)
    .rotationEffect(.degrees(Double(dragOffset.width / 18)))
    .shadow(radius: 16, y: 8)
    .animation(.easeOut(duration: 0.2), value: dragOffset)
    .sheet(isPresented: $showMetadata) {
      PhotoMetadataSheetView(vm: vm)
    }
    .uiTestContainer(
      AccessibilityID.reviewCard,
      value: "\(Int(lastDragTranslation.width)),\(Int(lastDragTranslation.height))")
  }

  private func expand() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      expandedPhoto = photo
    }
  }

  /// Crossing `fullScreenZoomThreshold` mid-gesture hands off to
  /// `expand()` immediately, so the card keeps growing continuously
  /// into full screen instead of bouncing back and popping open.
  private var pinchToZoom: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        if value > fullScreenZoomThreshold {
          zoomScale = 1.0
          expand()
        } else {
          zoomScale = value
        }
      }
      .onEnded { value in
        guard value <= fullScreenZoomThreshold else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
          zoomScale = 1.0
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged {
        dragOffset = $0.translation
        lastDragTranslation = $0.translation
      }
      .onEnded { value in
        let dx = value.translation.width
        let dy = value.translation.height
        if dx > 90 {
          vm.decide(index: vm.currentIndex, decision: .keep)
        } else if dy > 90 && abs(dy) > abs(dx) {
          vm.decide(index: vm.currentIndex, decision: .pendingDelete)
        } else if dx < -90 && abs(dx) > abs(dy) && vm.canUndo {
          vm.quickUndo()
        } else if dy < -90 && abs(dy) > abs(dx) {
          vm.showMetadataSheet(for: photo.id)
          showMetadata = true
        }
        dragOffset = .zero
      }
  }

  private var infoBadge: some View {
    Button {
      vm.showMetadataSheet(for: photo.id)
      showMetadata = true
    } label: {
      Image(systemName: "info.circle.fill")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .padding(12)
  }

  /// Shown on a photo already marked for conversion; tapping moves on without changing it.
  private var conversionMarker: some View {
    Button {
      vm.decide(index: vm.currentIndex, decision: .convertToStill)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "livephoto.slash")
        Text("Converts to still")
        Image(systemName: "chevron.right")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(ReviewDecision.convertToStill.tint.opacity(0.85), in: Capsule())
    }
    .buttonStyle(.plain)
    .padding(.bottom, 12)
  }

  private var topBar: some View {
    ZStack {
      LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
        .frame(height: 60)

      HStack {
        if !photo.dateLabel.isEmpty {
          Text(photo.dateLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
        }
        Spacer()
      }
      .padding(.horizontal, 14)
    }
    .frame(height: 60)
  }

  private var swipeUpHint: some View {
    let hintOpacity = min(1, max(0, -dragOffset.height / 90))
    return ZStack {
      RoundedRectangle(cornerRadius: 26)
        .fill(Color.black.opacity(0.6))
      VStack {
        Spacer()
        SwipeUpHintBadge()
          .padding(.bottom, 32)
      }
    }
    .frame(width: maxSize.width, height: maxSize.height)
    .opacity(hintOpacity)
  }
}

/// Hints that the swipe-up gesture (metadata) is about to trigger.
private struct SwipeUpHintBadge: View {
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: "chevron.up")
        .font(.system(size: 16, weight: .bold))
      Text("Swipe up")
        .font(.headline)
    }
    .foregroundStyle(.white)
  }
}

/// Dims the photo and names a decision or swipe action, with the same colored circle
/// as the control bar's buttons; swallows taps.
struct DecisionOverlay: View {
  let icon: String
  let title: String
  let tint: Color

  init(icon: String, title: String, tint: Color) {
    self.icon = icon
    self.title = title
    self.tint = tint
  }

  init(decision: ReviewDecision) {
    switch decision {
    case .keep: self.init(icon: "checkmark", title: "Kept", tint: decision.tint)
    case .pendingDelete:
      self.init(icon: "trash", title: "Marked for deletion", tint: decision.tint)
    case .convertToStill:
      self.init(icon: "livephoto.slash", title: "Marked for conversion", tint: decision.tint)
    case .undecided: self.init(icon: "questionmark", title: "Undecided", tint: decision.tint)
    }
  }

  static var undo: DecisionOverlay {
    DecisionOverlay(icon: "arrow.uturn.backward", title: "Undo", tint: .secondary)
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.6)
      VStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 64, height: 64)
          .background(Circle().fill(tint.opacity(0.25)))
        Text(title)
          .font(.headline)
          .foregroundStyle(.white)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {}
  }
}
