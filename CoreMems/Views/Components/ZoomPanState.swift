// CoreMems/Views/Components/ZoomPanState.swift
import SwiftUI

/// Zoom, pan and drag-to-dismiss state of a full-screen photo. Zoom persists with no
/// bounce-back; while zoomed a drag pans, and at 1x it drags the photo toward dismissal.
struct ZoomPanState: Equatable {
  static let maxScale: CGFloat = 5.0
  static let doubleTapScale: CGFloat = 2.5
  static let dismissThreshold: CGFloat = 120
  static let fadeDistance: CGFloat = 400
  static let zoomAnimation = Animation.spring(response: 0.3, dampingFraction: 0.75)
  static let springBackAnimation = Animation.spring(response: 0.35, dampingFraction: 0.75)

  private static let zoomedThreshold: CGFloat = 1.01
  private static let restThreshold: CGFloat = 1.05

  private(set) var scale: CGFloat = 1.0
  private(set) var panOffset: CGSize = .zero
  private(set) var dismissDrag: CGSize = .zero
  private var lastScale: CGFloat = 1.0
  private var lastPanOffset: CGSize = .zero

  var isZoomed: Bool { scale > Self.zoomedThreshold }

  /// The photo's total offset from center: its pan plus any dismiss drag.
  var offset: CGSize {
    CGSize(
      width: panOffset.width + dismissDrag.width, height: panOffset.height + dismissDrag.height)
  }

  /// 1 at rest, fading toward 0 as the photo is dragged away.
  private var dismissFade: Double {
    max(0, 1 - hypot(dismissDrag.width, dismissDrag.height) / Self.fadeDistance)
  }

  /// The backdrop fades while dragging to dismiss, and stays solid while zoomed.
  var backgroundOpacity: Double { isZoomed ? 1 : dismissFade }

  /// Surrounding controls fade while dragging to dismiss, and hide while zoomed.
  var chromeOpacity: Double { isZoomed ? 0 : dismissFade }

  /// Whether a finished pinch left the photo close enough to 1x to snap back to it.
  var isNearRest: Bool { scale <= Self.restThreshold }

  mutating func pinch(by magnification: CGFloat) {
    scale = min(max(lastScale * magnification, 1.0), Self.maxScale)
  }

  mutating func endPinch() {
    lastScale = scale
  }

  mutating func drag(by translation: CGSize) {
    if isZoomed {
      panOffset = CGSize(
        width: lastPanOffset.width + translation.width,
        height: lastPanOffset.height + translation.height)
    } else {
      dismissDrag = translation
    }
  }

  /// Settles a drag; returns whether it was long enough to dismiss. A drag that doesn't
  /// dismiss should be followed by `cancelDismissDrag()`.
  mutating func endDrag(translation: CGSize) -> Bool {
    if isZoomed {
      lastPanOffset = panOffset
      return false
    }
    return hypot(translation.width, translation.height) > Self.dismissThreshold
  }

  mutating func cancelDismissDrag() {
    dismissDrag = .zero
  }

  mutating func toggleZoom() {
    if isZoomed {
      reset()
    } else {
      scale = Self.doubleTapScale
      lastScale = Self.doubleTapScale
    }
  }

  mutating func reset() {
    self = ZoomPanState()
  }
}

extension View {
  /// Shows the photo at `state`'s zoom and offset, and drives `state` with pinch, drag and
  /// double-tap. `gestures` turns those gestures on and off; `onDismiss` runs when a drag at
  /// 1x is long enough.
  func zoomPanDismiss(
    _ state: Binding<ZoomPanState>, gestures: GestureMask = .all, onDismiss: @escaping () -> Void
  ) -> some View {
    modifier(ZoomPanDismiss(state: state, gestures: gestures, onDismiss: onDismiss))
  }
}

private struct ZoomPanDismiss: ViewModifier {
  @Binding var state: ZoomPanState
  let gestures: GestureMask
  let onDismiss: () -> Void

  func body(content: Content) -> some View {
    content
      .scaleEffect(state.scale)
      .offset(state.offset)
      .gesture(magnification, including: gestures)
      .simultaneousGesture(drag, including: gestures)
      .gesture(
        TapGesture(count: 2).onEnded {
          withAnimation(ZoomPanState.zoomAnimation) { state.toggleZoom() }
        }, including: gestures)
  }

  private var magnification: some Gesture {
    MagnificationGesture()
      .onChanged { state.pinch(by: $0) }
      .onEnded { _ in
        state.endPinch()
        if state.isNearRest {
          withAnimation(ZoomPanState.zoomAnimation) { state.reset() }
        }
      }
  }

  private var drag: some Gesture {
    DragGesture()
      .onChanged { state.drag(by: $0.translation) }
      .onEnded { value in
        if state.endDrag(translation: value.translation) {
          onDismiss()
        } else {
          withAnimation(ZoomPanState.springBackAnimation) { state.cancelDismissDrag() }
        }
      }
  }
}
