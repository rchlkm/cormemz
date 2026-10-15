// CoreMems/Views/Components/VideoPlayerView.swift
import AVFoundation
import SwiftUI

/// Autoplaying playback of a video asset, with sound, a play/pause button, a
/// mute toggle, a 2× speed lock, and a scrub bar between the current time and the length.
/// Holding the picture plays at 2× for as long as it is held.
/// Loads through `playback`, which controls outside the player can share,
/// analogous to how `LivePhotoPlayerView` is fed an already-loaded `PHLivePhoto`.
struct VideoPlayerView: View {
  @ObservedObject var playback: VideoPlayback
  let assetIdentifier: String
  /// Counterclockwise quarter turns applied to the picture; the controls stay upright.
  var quarterTurns = 0
  /// The part played, in seconds; `nil` plays all of it.
  var playbackRange: ClosedRange<Double>?
  /// Off when other controls, such as the editor's trim bar, stand in for the transport bar.
  var showsTransport = true
  /// Space kept clear below the transport bar.
  var transportBottomInset = VideoPlayerView.defaultTransportInset

  static let defaultTransportInset: CGFloat = 12

  private static let holdDuration: TimeInterval = 0.3

  var body: some View {
    Group {
      if let player = playback.player {
        ZStack(alignment: .bottom) {
          PlayerLayerRepresentable(player: player)
            .rotated(quarterTurns: quarterTurns)
            .onLongPressGesture(
              minimumDuration: Self.holdDuration,
              perform: { playback.setSpeedHeld(true) },
              onPressingChanged: { if !$0 { playback.setSpeedHeld(false) } })
          if showsTransport { transportBar }
        }
      } else if playback.loadFailed {
        AssetPlaceholderView(state: .failed(icon: "video.slash"))
      } else {
        AssetPlaceholderView(state: .loading)
      }
    }
    .task(id: assetIdentifier) {
      await playback.load(assetIdentifier: assetIdentifier, range: playbackRange)
    }
    .onChange(of: playbackRange) { _, range in
      playback.setRange(range)
    }
    .onDisappear {
      playback.pause()
    }
  }

  private var transportBar: some View {
    HStack(spacing: 10) {
      PlayPauseButton(playback: playback, surface: .scrim)
      PlaybackTimeLabel(seconds: playback.position)
      ScrubBar(progress: scrubBinding, isScrubbing: $playback.isScrubbing)
      PlaybackTimeLabel(seconds: playback.duration)

      Button(action: playback.toggleSpeedLock) {
        Image(systemName: "forward.fill")
      }
      .buttonStyle(IconButtonStyle(size: .small, surface: speedLockSurface))
      .accessibilityLabel("Lock 2× speed")
      .accessibilityValue(playback.isSpeedLocked ? "On" : "Off")

      Button(action: playback.toggleMute) {
        Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
      }
      .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    }
    .padding(.horizontal, 12)
    .padding(.bottom, transportBottomInset)
    .padding(.top, 24)
    .background(
      LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
    )
  }

  private var speedLockSurface: IconButtonSurface {
    playback.isSpeedLocked ? .material(.yellow) : .scrim
  }

  /// Reads the live playback position as a fraction; writes seek to wherever the scrub bar
  /// is dragged.
  private var scrubBinding: Binding<Double> {
    Binding(
      get: { playback.duration > 0 ? playback.position / playback.duration : 0 },
      set: { playback.seek(to: $0 * playback.duration) })
  }
}

/// A slim, draggable progress track. `.highPriorityGesture` claims a drag
/// starting on the bar before the browse card's own swipe-to-decide gesture
/// can see it, so scrubbing never gets mistaken for a swipe.
private struct ScrubBar: View {
  @Binding var progress: Double
  @Binding var isScrubbing: Bool

  private static let trackHeight: CGFloat = 4
  private static let hitHeight: CGFloat = 20

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.3))
        Capsule().fill(.white).frame(width: width * progress)
      }
      .frame(height: Self.trackHeight)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .highPriorityGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            isScrubbing = true
            progress = min(1, max(0, value.location.x / width))
          }
          .onEnded { _ in
            isScrubbing = false
          }
      )
    }
    .frame(height: Self.hitHeight)
  }
}

/// Bridges an `AVPlayer` into SwiftUI via a bare `AVPlayerLayer` — no
/// native transport controls, matching the browse card's own chrome.
private struct PlayerLayerRepresentable: UIViewRepresentable {
  let player: AVPlayer

  func makeUIView(context: Context) -> PlayerLayerView { PlayerLayerView() }

  func updateUIView(_ uiView: PlayerLayerView, context: Context) {
    uiView.setPlayer(player)
  }
}

private final class PlayerLayerView: UIView {
  override static var layerClass: AnyClass { AVPlayerLayer.self }
  private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

  func setPlayer(_ player: AVPlayer?) {
    playerLayer.player = player
    playerLayer.videoGravity = .resizeAspect
  }
}
