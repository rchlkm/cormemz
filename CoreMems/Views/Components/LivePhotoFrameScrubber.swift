// CoreMems/Views/Components/LivePhotoFrameScrubber.swift
import SwiftUI

/// A Live Photo's video as a strip of frames with a marker on the one shown.
/// Drag along it to move to another frame.
struct LivePhotoFrameScrubber: View {
  let frames: LivePhotoFrames
  @Binding var time: Double

  @State private var thumbnails: [UIImage?] = Array(repeating: nil, count: thumbnailCount)

  private static let thumbnailCount = 10
  private static let height: CGFloat = 44
  private static let cornerRadius: CGFloat = 6
  private static let markerWidth: CGFloat = 4
  /// How far one accessibility adjustment moves the marker, in seconds.
  private static let accessibilityStep = 0.1

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      ZStack(alignment: .leading) {
        HStack(spacing: 0) {
          ForEach(thumbnails.indices, id: \.self) { index in
            thumbnail(thumbnails[index])
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .strokeBorder(.yellow, lineWidth: Self.markerWidth)
          .frame(width: Self.markerWidth * 3)
          .offset(x: markerOffset(in: width))
          .allowsHitTesting(false)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            time = Double(min(max(value.location.x / width, 0), 1)) * frames.duration
          }
      )
    }
    .frame(height: Self.height)
    .accessibilityElement()
    .accessibilityLabel("Frame")
    .accessibilityValue(time.clockText)
    .accessibilityAdjustableAction { direction in
      let step = direction == .increment ? Self.accessibilityStep : -Self.accessibilityStep
      time = min(max(time + step, 0), frames.duration)
    }
    .task(id: frames.duration) { await loadThumbnails() }
  }

  private func thumbnail(_ image: UIImage?) -> some View {
    Color.white.opacity(0.2)
      .overlay {
        if let image {
          Image(uiImage: image).resizable().scaledToFill()
        }
      }
      .clipped()
  }

  private func markerOffset(in width: CGFloat) -> CGFloat {
    let track = width - Self.markerWidth * 3
    return CGFloat(time / frames.duration) * track
  }

  private func loadThumbnails() async {
    let count = Self.thumbnailCount
    let side = Self.height * UIScreen.main.scale * 2
    for index in 0..<count {
      let seconds = frames.duration * (Double(index) + 0.5) / Double(count)
      thumbnails[index] = await frames.image(at: seconds, maxSize: CGSize(width: side, height: side))
    }
  }
}
