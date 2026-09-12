// CoreMems/Views/Components/FullScreenPhotoView.swift
import SwiftUI

/// Full-screen photo viewer: pinch to zoom, double-tap to toggle zoom,
/// drag to pan while zoomed, swipe down to dismiss while at 1x.
struct FullScreenPhotoView: View {
  let photo: SessionPhoto
  @Environment(\.dismiss) private var dismiss

  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var dragToDismiss: CGSize = .zero

  private let maxScale: CGFloat = 4

  var body: some View {
    ZStack {
      Color.black
        .opacity(1 - min(1, abs(dragToDismiss.height) / 400))
        .ignoresSafeArea()

      GeometryReader { geo in
        AdaptiveAssetImage(
          photo: photo,
          targetSize: CGSize(width: geo.size.width * 2, height: geo.size.height * 2),
          fitWithin: geo.size
        )
        .frame(width: geo.size.width, height: geo.size.height)
        .scaleEffect(scale)
        .offset(x: offset.width, y: offset.height + dragToDismiss.height)
        .contentShape(Rectangle())
        .gesture(magnification)
        .simultaneousGesture(pan)
        .gesture(dismissDrag)
        .onTapGesture(count: 2) { toggleZoom() }
      }

      VStack {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)
              .padding(10)
              .background(.black.opacity(0.4), in: Circle())
          }
          .padding()
        }
        Spacer()
      }
    }
    .statusBarHidden()
  }

  private var magnification: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        scale = min(maxScale, max(1, lastScale * value))
      }
      .onEnded { _ in
        lastScale = scale
        if scale <= 1.01 { withAnimation(.spring()) { resetZoom() } }
      }
  }

  private var pan: some Gesture {
    DragGesture()
      .onChanged { value in
        guard scale > 1.01 else { return }
        offset = CGSize(
          width: lastOffset.width + value.translation.width,
          height: lastOffset.height + value.translation.height)
      }
      .onEnded { _ in
        guard scale > 1.01 else { return }
        lastOffset = offset
      }
  }

  /// Only used to swipe-dismiss while un-zoomed — panning while
  /// zoomed is handled by `pan` above instead.
  private var dismissDrag: some Gesture {
    DragGesture()
      .onChanged { value in
        guard scale <= 1.01 else { return }
        dragToDismiss = value.translation
      }
      .onEnded { value in
        guard scale <= 1.01 else { return }
        if abs(value.translation.height) > 120 {
          dismiss()
        } else {
          withAnimation(.spring()) { dragToDismiss = .zero }
        }
      }
  }

  private func toggleZoom() {
    withAnimation(.spring()) {
      if scale > 1.01 {
        resetZoom()
      } else {
        scale = 2.5
        lastScale = 2.5
      }
    }
  }

  private func resetZoom() {
    scale = 1
    lastScale = 1
    offset = .zero
    lastOffset = .zero
  }
}
