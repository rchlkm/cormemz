// CoreMems/Services/LivePhotoFrames.swift
import AVFoundation
import UIKit

/// The video frames of a Live Photo, to look through. Holds a temporary copy of
/// the paired video, removed along with this object.
nonisolated final class LivePhotoFrames: Sendable {
  /// Length of the Live Photo's video, in seconds.
  let duration: Double
  /// The key photo's moment in the video, in seconds.
  let keyPhotoTime: Double
  private let videoURL: URL

  init(videoURL: URL, duration: Double, keyPhotoTime: Double) {
    self.videoURL = videoURL
    self.duration = duration
    self.keyPhotoTime = keyPhotoTime
  }

  deinit {
    try? FileManager.default.removeItem(at: videoURL)
  }

  /// The frame at `seconds`, upright and fitting within `maxSize` pixels.
  func image(at seconds: Double, maxSize: CGSize) async -> UIImage? {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = maxSize
    let time = CMTime(seconds: min(max(seconds, 0), duration), preferredTimescale: 600)
    guard let frame = try? await generator.image(at: time).image else { return nil }
    return UIImage(cgImage: frame)
  }
}
