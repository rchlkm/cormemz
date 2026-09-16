// CoreMems/Views/Components/PhotoActionRailView.swift
import SwiftUI

/// Floating rail of photo-editing actions — favorite, album, caption,
/// keywords — meant to sit on top of a review card. The host positions
/// it outside the card's swipe-transform layer so swiping the photo
/// never moves it; this view only handles the person dragging it to a
/// new spot themselves.
///
/// Caption and keyword tagging have no backing feature yet, so those
/// buttons render dimmed and don't respond to taps.
struct PhotoActionRailView: View {
  let isFavorite: Bool
  let containerSize: CGSize
  let onToggleFavorite: () -> Void
  let onAssignAlbum: () -> Void

  /// Position, as an offset from the default (trailing edge, vertically
  /// centered) spot. Lives for as long as this view does — it isn't
  /// persisted across sessions or app launches.
  @State private var offset: CGSize = .zero
  @GestureState private var dragTranslation: CGSize = .zero

  /// Rough footprint of the rail's capsule, used only to keep it
  /// draggable within `containerSize` instead of off the edge.
  private let estimatedSize = CGSize(width: 70, height: 270)

  var body: some View {
    VStack(spacing: 4) {
      actionRailButton(
        systemImage: isFavorite ? "heart.fill" : "heart",
        tint: isFavorite ? .pink : .white,
        action: onToggleFavorite
      )
      actionRailButton(systemImage: "folder.badge.plus", tint: .white, action: onAssignAlbum)
      actionRailButton(systemImage: "text.bubble", tint: .white, enabled: false) {}
      Image(systemName: "line.3.horizontal")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.45))
        .padding(.bottom, 6)

    }
    .padding(.vertical, 16)
    .padding(.horizontal, 12)
    .background(.black.opacity(0.4), in: Capsule())
    .padding(.trailing, 10)
    .offset(
      x: offset.width + dragTranslation.width,
      y: offset.height + dragTranslation.height
    )
    .gesture(dragGesture)
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .updating($dragTranslation) { value, state, _ in
        state = value.translation
      }
      .onEnded { value in
        let proposed = CGSize(
          width: offset.width + value.translation.width,
          height: offset.height + value.translation.height
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          offset = clampedOffset(proposed)
        }
      }
  }

  /// The rail defaults to the trailing edge, so a positive `width`
  /// would push it off-screen to the right — clamped to 0 — while a
  /// negative `width` drags it left, clamped so it can't cross the
  /// container's leading edge.
  private func clampedOffset(_ proposed: CGSize) -> CGSize {
    let maxLeftShift = max(0, containerSize.width - estimatedSize.width - 10)
    let maxY = max(0, (containerSize.height - estimatedSize.height) / 2)
    return CGSize(
      width: min(max(proposed.width, -maxLeftShift), 0),
      height: min(max(proposed.height, -maxY), maxY)
    )
  }

  private func actionRailButton(
    systemImage: String,
    tint: Color,
    enabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 22))
        .foregroundStyle(enabled ? tint : tint.opacity(0.35))
        .frame(width: 46, height: 46)
    }
    .disabled(!enabled)
  }
}
