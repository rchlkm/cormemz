// CoreMems/Views/Components/VideoTransportControls.swift
import SwiftUI

/// Play/pause button for a `VideoPlayback`.
struct PlayPauseButton: View {
  @ObservedObject var playback: VideoPlayback
  let surface: IconButtonSurface

  var body: some View {
    Button(action: playback.togglePlayback) {
      Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: surface))
    .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
  }
}

/// A playback position or length as minutes and seconds, drawn over video.
struct PlaybackTimeLabel: View {
  let seconds: Double

  var body: some View {
    Text(seconds.clockText)
      .font(.caption.monospacedDigit())
      .foregroundStyle(.white)
      .shadow(radius: 2)
  }
}
