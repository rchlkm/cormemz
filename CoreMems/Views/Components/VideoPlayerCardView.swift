// CoreMems/Views/Components/VideoPlayerCardView.swift
import AVFoundation
import SwiftUI

/// Autoplaying playback of a video asset, with sound, a play/pause button, a
/// mute toggle, and a scrub bar. Plays once and stops at the end — no
/// looping; pressing play again after that replays from the start. Loads
/// its own `AVPlayerItem` via `VideoAssetLoader`, analogous to how
/// `LivePhotoPlayerView` is fed an already-loaded `PHLivePhoto`.
struct VideoPlayerCardView: View {
  let assetIdentifier: String

  @State private var player: AVPlayer?
  @State private var timeObserver: Any?
  @State private var endObserver: NSObjectProtocol?
  @State private var isPlaying = true
  @State private var isMuted = false
  @State private var duration: Double = 0
  @State private var progress: Double = 0
  @State private var isScrubbing = false
  @State private var loadFailed = false

  var body: some View {
    Group {
      if let player {
        ZStack(alignment: .bottom) {
          PlayerLayerRepresentable(player: player)
          transportBar
        }
      } else if loadFailed {
        AssetPlaceholderView(state: .failed(icon: "video.slash"))
      } else {
        AssetPlaceholderView(state: .loading)
      }
    }
    .task(id: assetIdentifier) {
      await load()
    }
    .onDisappear {
      player?.pause()
    }
  }

  private var transportBar: some View {
    HStack(spacing: 10) {
      Button(action: togglePlayback) {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
      }
      .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))

      ScrubBar(progress: scrubBinding, isScrubbing: $isScrubbing)

      Button(action: toggleMute) {
        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
      }
      .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
    .padding(.top, 24)
    .background(
      LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
    )
  }

  /// Reads the live playback position; writes seek to wherever the scrub bar is dragged.
  private var scrubBinding: Binding<Double> {
    Binding(
      get: { progress },
      set: { newValue in
        progress = newValue
        guard let player, duration > 0 else { return }
        let time = CMTime(seconds: newValue * duration, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
      })
  }

  private func togglePlayback() {
    guard let player else { return }
    if isPlaying {
      player.pause()
    } else {
      // Replay from the start rather than doing nothing when already at the end.
      if progress >= 0.999 {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        progress = 0
      }
      player.play()
    }
    isPlaying.toggle()
  }

  private func toggleMute() {
    isMuted.toggle()
    player?.isMuted = isMuted
  }

  private func load() async {
    reset()
    guard let item = await VideoAssetLoader.shared.playerItem(for: assetIdentifier) else {
      loadFailed = true
      return
    }
    duration = (try? await item.asset.load(.duration).seconds) ?? 0
    if !duration.isFinite { duration = 0 }

    // The card this view belongs to may already be gone by the time the awaits above
    // resolve — task cancellation is cooperative, so without this check a stale load
    // would still spin up a player nothing is left to ever pause.
    guard !Task.isCancelled else { return }

    try? AVAudioSession.sharedInstance().setCategory(.playback)
    let newPlayer = AVPlayer(playerItem: item)
    newPlayer.isMuted = isMuted
    player = newPlayer
    observeTime(on: newPlayer)
    observeEnd(of: item)
    newPlayer.play()
    isPlaying = true
  }

  private func observeTime(on player: AVPlayer) {
    let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
      guard duration > 0, !isScrubbing else { return }
      progress = min(1, max(0, time.seconds / duration))
    }
  }

  private func observeEnd(of item: AVPlayerItem) {
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { _ in
      isPlaying = false
      progress = 1
    }
  }

  private func reset() {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    timeObserver = nil
    endObserver = nil
    player = nil
    isPlaying = true
    progress = 0
    duration = 0
    loadFailed = false
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
