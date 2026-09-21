// CoreMems/Views/Components/FullScreenPhotoView.swift
import SwiftUI

/// Full-screen photo viewer. Pinch to zoom in/out (persists — no
/// bounce-back — matching a normal photo viewer rather than the
/// card's "peek" zoom). While zoomed, dragging pans around the image.
/// While at 1x, dragging in any direction dismisses past a threshold,
/// or springs back to center if it doesn't clear it. Double-tap
/// toggles zoom as a shortcut.
struct FullScreenPhotoView: View {
  let photo: SessionPhoto
  /// Shows what the photo is marked for with an Undo action; the viewer closes once it runs.
  var onUndo: (() -> Void)? = nil

  @Environment(\.dismiss) private var dismiss

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero
  @State private var dismissDrag: CGSize = .zero

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

      AdaptiveAssetImage(
        photo: photo, targetSize: UIScreen.main.bounds.size, contentMode: .fit
      )
      .scaleEffect(scale)
      .offset(x: panOffset.width + dismissDrag.width, y: panOffset.height + dismissDrag.height)
      .gesture(magnification)
      .simultaneousGesture(dragGesture)
      .onTapGesture(count: 2) { toggleZoom() }
    }
    .overlay(alignment: .topTrailing) { closeButton.opacity(chromeOpacity) }
    .overlay(alignment: .bottom) { undoBar.opacity(chromeOpacity) }
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.photoViewer)
  }

  private var chromeOpacity: Double {
    isZoomed ? 0 : max(0, 1 - hypot(dismissDrag.width, dismissDrag.height) / fadeDistance)
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .accessibilityLabel("Close")
    .disabled(isZoomed)
    .padding(16)
  }

  @ViewBuilder
  private var undoBar: some View {
    if let onUndo {
      let status = DecisionOverlay(decision: photo.decision)
      VStack(spacing: 12) {
        Label {
          Text(status.title).foregroundStyle(.white)
        } icon: {
          Image(systemName: status.icon).foregroundStyle(status.tint)
        }
        .font(.headline)

        Button {
          dismiss()
          onUndo()
        } label: {
          Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(ActionButtonStyle(role: .secondary))
        .accessibilityIdentifier(AccessibilityID.photoViewerUndo)
        .disabled(isZoomed)
      }
      .environment(\.colorScheme, .dark)
      .padding(26)
      .frame(maxWidth: .infinity)
      .background(
        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
      )
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
            dismiss()
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
}