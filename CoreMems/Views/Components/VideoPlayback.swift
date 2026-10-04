// CoreMems/Views/Components/VideoPlayback.swift
import AVFoundation
import Combine

/// Playback of one video asset, shared by the player and any controls outside it, such as the
/// editor's trim bar. Plays once and stops at the end; playing again replays from the start.
final class VideoPlayback: ObservableObject {
  @Published private(set) var player: AVPlayer?
  @Published private(set) var isPlaying = true
  @Published private(set) var isMuted = false
  @Published private(set) var duration: Double = 0
  /// The playback position in seconds.
  @Published private(set) var position: Double = 0
  @Published private(set) var loadFailed = false
  /// While set, playback doesn't move `position`, so it stays where it's dragged.
  @Published var isScrubbing = false
  /// The part played, in seconds; `nil` plays all of it.
  private(set) var range: ClosedRange<Double>?

  private var timeObserver: Any?
  private var endObserver: AnyCancellable?

  var start: Double { range?.lowerBound ?? 0 }
  var end: Double { range?.upperBound ?? duration }

  func load(assetIdentifier: String, range: ClosedRange<Double>?) async {
    reset()
    self.range = range
    guard let item = await VideoAssetLoader.shared.playerItem(for: assetIdentifier) else {
      loadFailed = true
      return
    }
    let loaded = (try? await item.asset.load(.duration).seconds) ?? 0
    duration = loaded.isFinite ? loaded : 0

    // The view this belongs to may already be gone by the time the awaits above resolve;
    // without this check a stale load would spin up a player nothing is left to pause.
    guard !Task.isCancelled else { return }

    try? AVAudioSession.sharedInstance().setCategory(.playback)
    let newPlayer = AVPlayer(playerItem: item)
    newPlayer.isMuted = isMuted
    player = newPlayer
    observeTime(on: newPlayer)
    observeEnd(of: item)
    limitPlayback()
    if range != nil { seek(to: start) }
    newPlayer.play()
    isPlaying = true
  }

  /// Plays only `range`, pausing on the frame at whichever end moved.
  func setRange(_ newRange: ClosedRange<Double>?) {
    let startMoved = newRange?.lowerBound != range?.lowerBound
    range = newRange
    pause()
    limitPlayback()
    seek(to: startMoved ? start : end)
  }

  /// Moves to `seconds`, kept within the part played.
  func seek(to seconds: Double) {
    guard let player, duration > 0 else { return }
    position = min(max(seconds, start), end)
    let time = CMTime(seconds: position, preferredTimescale: 600)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  func togglePlayback() {
    guard let player else { return }
    if isPlaying {
      pause()
      return
    }
    // Replay from the start rather than doing nothing when already at the end.
    if position >= end - 0.001 * duration || position < start {
      seek(to: start)
    }
    player.play()
    isPlaying = true
  }

  func pause() {
    player?.pause()
    isPlaying = false
  }

  func toggleMute() {
    isMuted.toggle()
    player?.isMuted = isMuted
  }

  /// Ends playback at the end of the part played.
  private func limitPlayback() {
    player?.currentItem?.forwardPlaybackEndTime =
      range.map { CMTime(seconds: $0.upperBound, preferredTimescale: 600) } ?? .invalid
  }

  private func observeTime(on player: AVPlayer) {
    let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      MainActor.assumeIsolated {
        guard let self, !self.isScrubbing else { return }
        self.position = min(max(time.seconds, 0), self.duration)
      }
    }
  }

  private func observeEnd(of item: AVPlayerItem) {
    endObserver = NotificationCenter.default
      .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.isPlaying = false
        self.position = self.end
      }
  }

  private func reset() {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
    endObserver = nil
    player = nil
    isPlaying = true
    position = 0
    duration = 0
    loadFailed = false
  }
}
