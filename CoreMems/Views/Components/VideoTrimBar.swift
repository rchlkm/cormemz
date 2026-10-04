// CoreMems/Views/Components/VideoTrimBar.swift
import SwiftUI

/// A video's timeline with a handle at each end of the part kept, as in the Photos trimmer.
/// It's also the scrubber: drag along it to move the playhead, with play beside it and the
/// playhead's time above it.
struct VideoTrimBar: View {
  @Binding var range: ClosedRange<Double>
  let duration: Double
  @ObservedObject var playback: VideoPlayback

  private enum End { case start, end }

  private static let coordinateSpace = "VideoTrimBar"
  private static let height: CGFloat = 44
  private static let handleWidth: CGFloat = 16
  private static let cornerRadius: CGFloat = 6
  private static let playheadWidth: CGFloat = 3
  /// Shortest part that can be kept, in seconds.
  private static let minimumLength: Double = 1
  /// How far one accessibility adjustment moves a handle, in seconds.
  private static let accessibilityStep: Double = 1

  private var minimumGap: Double { min(Self.minimumLength, duration) }

  var body: some View {
    VStack(spacing: 6) {
      PlaybackTimeLabel(seconds: playback.position)
      HStack(spacing: 10) {
        PlayPauseButton(playback: playback, surface: .bare(.white))
        timeline
      }
    }
  }

  private var timeline: some View {
    GeometryReader { proxy in
      let track = max(proxy.size.width - 2 * Self.handleWidth, 1)
      let x = { (seconds: Double) in CGFloat(seconds / duration) * track }
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: Self.cornerRadius).fill(.white.opacity(0.2))
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .strokeBorder(.yellow, lineWidth: 3)
          .frame(width: x(range.upperBound) - x(range.lowerBound) + 2 * Self.handleWidth)
          .offset(x: x(range.lowerBound))
        handle(.start, track: track)
          .offset(x: x(range.lowerBound))
        handle(.end, track: track)
          .offset(x: x(range.upperBound) + Self.handleWidth)
        Capsule()
          .fill(.white)
          .frame(width: Self.playheadWidth)
          .offset(x: x(playback.position) + Self.handleWidth - Self.playheadWidth / 2)
          .allowsHitTesting(false)
      }
      .coordinateSpace(.named(Self.coordinateSpace))
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
          .onChanged { value in
            playback.pause()
            playback.seek(to: Double((value.location.x - Self.handleWidth) / track) * duration)
          }
      )
    }
    .frame(height: Self.height)
  }

  private func handle(_ end: End, track: CGFloat) -> some View {
    UnevenRoundedRectangle(
      topLeadingRadius: end == .start ? Self.cornerRadius : 0,
      bottomLeadingRadius: end == .start ? Self.cornerRadius : 0,
      bottomTrailingRadius: end == .end ? Self.cornerRadius : 0,
      topTrailingRadius: end == .end ? Self.cornerRadius : 0
    )
    .fill(.yellow)
    .overlay {
      Image(systemName: end == .start ? "chevron.compact.left" : "chevron.compact.right")
        .font(.body.weight(.bold))
        .foregroundStyle(.black)
    }
    .frame(width: Self.handleWidth)
    .contentShape(Rectangle())
    .highPriorityGesture(
      DragGesture(coordinateSpace: .named(Self.coordinateSpace))
        .onChanged { value in
          // The handle's center follows the finger; the start handle sits half a width in.
          let inset = end == .start ? Self.handleWidth / 2 : Self.handleWidth * 1.5
          move(end, to: Double((value.location.x - inset) / track) * duration)
        }
    )
    .accessibilityElement()
    .accessibilityLabel(end == .start ? "Start" : "End")
    .accessibilityValue((end == .start ? range.lowerBound : range.upperBound).clockText)
    .accessibilityAdjustableAction { direction in
      let current = end == .start ? range.lowerBound : range.upperBound
      let step = direction == .increment ? Self.accessibilityStep : -Self.accessibilityStep
      move(end, to: current + step)
    }
  }

  /// Moves one end, keeping it on the timeline and at least `minimumGap` from the other.
  private func move(_ end: End, to seconds: Double) {
    switch end {
    case .start:
      range = min(max(seconds, 0), range.upperBound - minimumGap)...range.upperBound
    case .end:
      range = range.lowerBound...max(min(seconds, duration), range.lowerBound + minimumGap)
    }
  }
}
