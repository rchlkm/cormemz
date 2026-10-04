// CoreMems/Views/Components/LivePhotoFrameState.swift
import Combine
import UIKit

/// The frames of a Live Photo being looked through, and the one shown in place of its still.
final class LivePhotoFrameState: ObservableObject {
  @Published private(set) var frames: LivePhotoFrames?
  /// The moment being looked at, in seconds; `nil` while the frames are closed.
  @Published var time: Double?
  @Published private(set) var image: UIImage?

  /// Shows a Live Photo's frames at its key photo; other photos have none.
  func open(for photo: SessionPhoto) async {
    guard photo.isLivePhoto, time == nil else { return }
    if frames == nil { frames = await LivePhotoLoader.shared.frames(for: photo.assetIdentifier) }
    time = frames?.keyPhotoTime
  }

  func close() {
    time = nil
    image = nil
  }

  /// Renders the frame at `time` at screen resolution.
  func loadImage() async {
    guard let time, let frames else { return }
    let scale = UIScreen.main.scale
    let size = UIScreen.main.bounds.size
    image = await frames.image(
      at: time, maxSize: CGSize(width: size.width * scale, height: size.height * scale))
  }
}
