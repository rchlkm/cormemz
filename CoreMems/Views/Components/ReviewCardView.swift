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

  private static let topBarHeight: CGFloat = 60
  private static let decisionTagGap: CGFloat = 8

  /// Pinch scale past which the card hands off to full screen instead
  /// of bouncing back.
  private let fullScreenZoomThreshold: CGFloat = 1.6

  private var isExpanded: Bool { expandedPhoto != nil }

  /// The photo the card's chrome and actions refer to: the peeked-at neighbor, else the card's photo.
  private var subject: SessionPhoto { vm.focusedPhoto ?? photo }

  private var isShowingNeighborPreview: Bool {
    subject.id != photo.id && !isShowingLivePhoto
  }

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
    if vm.canGoBack && dx < 0 && abs(dx) > abs(dy) {
      return (.goBack, min(1, -dx / 90))
    }
    return nil
  }

  /// The swipe-up hint sits behind the photo, fixed in place, so dragging the
  /// photo upward opens a gap at its bottom edge that reveals the hint
  /// underneath — the hint itself never moves with the drag.
  private var swipableCard: some View {
    ZStack {
      SwipeUpHintView(size: maxSize, progress: min(1, max(0, -dragOffset.height / 90)))
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
      isEnabled: subject.isLivePhoto,
      assetIdentifier: subject.assetIdentifier,
      targetSize: livePhotoTargetSize,
      inlineLivePhoto: $inlineLivePhoto,
      isShowingLivePhoto: $isShowingLivePhoto
    )
    .scaleEffect(zoomScale)
    .gesture(pinchToZoom)
    .overlay {
      if let peek = vm.peek {
        PeekPreviewView(
          neighbors: vm.peekNeighbors, focusedID: peek.focusedID, maxSize: maxSize,
          isVisible: isShowingNeighborPreview)
      }
    }
    .overlay(alignment: .top) { topBar }
    .overlay(alignment: .top) {
      if vm.isPeeking || subject.decision != .convertToStill {
        PeekDecisionTag(decision: subject.decision)
          .padding(.top, Self.topBarHeight + Self.decisionTagGap)
      }
    }
    .overlay(alignment: .bottomLeading) {
      if subject.isLivePhoto {
        LivePhotoBadgeView(
          assetIdentifier: subject.assetIdentifier,
          targetSize: livePhotoTargetSize,
          inlineLivePhoto: $inlineLivePhoto,
          isShowingLivePhoto: $isShowingLivePhoto,
          onConvertToStill: { vm.decide(photoID: subject.id, decision: .convertToStill) }
        )
        .accessibilityIdentifier(AccessibilityID.liveBadge)
      }
    }
    .overlay(alignment: .bottom) {
      if !vm.isPeeking && photo.decision == .convertToStill {
        ConversionMarker { vm.decide(index: vm.currentIndex, decision: .convertToStill) }
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
    .onChange(of: subject.id) {
      inlineLivePhoto = nil
      isShowingLivePhoto = false
    }
    .uiTestContainer(
      AccessibilityID.reviewCard,
      value: "\(Int(lastDragTranslation.width)),\(Int(lastDragTranslation.height))")
  }

  private func expand() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      expandedPhoto = subject
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
        guard !vm.isPeeking else { return }
        dragOffset = $0.translation
        lastDragTranslation = $0.translation
      }
      .onEnded { value in
        let dx = value.translation.width
        let dy = value.translation.height
        guard !vm.isPeeking else {
          if dy > 90 && abs(dy) > abs(dx) { togglePeek() }
          return
        }
        if dx > 90 {
          vm.decide(index: vm.currentIndex, decision: .keep)
        } else if dy > 90 && abs(dy) > abs(dx) {
          vm.decide(index: vm.currentIndex, decision: .pendingDelete)
        } else if dx < -90 && abs(dx) > abs(dy) && vm.canGoBack {
          vm.goBack()
        } else if dy < -90 && abs(dy) > abs(dx) {
          togglePeek()
        }
        dragOffset = .zero
      }
  }

  private var infoBadge: some View {
    Button {
      vm.showMetadataSheet(for: subject.id)
      showMetadata = true
    } label: {
      Image(systemName: "info.circle.fill")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .padding(12)
  }

  private func togglePeek() {
    withAnimation(.snappy(duration: 0.2)) { vm.togglePeek() }
  }

  private var peekToggleButton: some View {
    Button {
      togglePeek()
    } label: {
      Image(systemName: vm.isPeeking ? "xmark" : "square.stack")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .accessibilityIdentifier(AccessibilityID.reviewPeekToggle)
  }

  private var topBar: some View {
    ZStack {
      LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
        .frame(height: Self.topBarHeight)

      HStack {
        if !subject.dateLabel.isEmpty {
          Text(subject.dateLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
        }
        Spacer()
        peekToggleButton
      }
      .padding(.horizontal, 14)
    }
    .frame(height: Self.topBarHeight)
  }
}
