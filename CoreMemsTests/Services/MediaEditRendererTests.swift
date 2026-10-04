// CoreMemsTests/Services/MediaEditRendererTests.swift
import CoreGraphics
import CoreImage
import CoreMedia
import Testing

@testable import CoreMems

@Suite("Media edit rendering")
struct MediaEditRendererTests {
  private let landscape = CGSize(width: 1920, height: 1080)

  @Test func noTurnsLeavesTheTransformAlone() {
    let transform = MediaEditRenderer.rotatedTransform(
      .identity, naturalSize: landscape, quarterTurns: 0)

    #expect(transform == .identity)
  }

  @Test func aQuarterTurnStandsALandscapeVideoUpright() {
    let transform = MediaEditRenderer.rotatedTransform(
      .identity, naturalSize: landscape, quarterTurns: 1)

    let frame = CGRect(origin: .zero, size: landscape).applying(transform)
    #expect(frame == CGRect(x: 0, y: 0, width: 1080, height: 1920))
    // Counterclockwise: the top-right corner moves to the top-left.
    #expect(CGPoint(x: 1920, y: 0).applying(transform) == .zero)
  }

  @Test func twoQuarterTurnsTurnTheVideoUpsideDown() {
    let transform = MediaEditRenderer.rotatedTransform(
      .identity, naturalSize: landscape, quarterTurns: 2)

    #expect(CGRect(origin: .zero, size: landscape).applying(transform).size == landscape)
    #expect(CGPoint(x: 1920, y: 1080).applying(transform) == .zero)
  }

  @Test func turnsBuildOnTheVideosExistingTransform() {
    // A portrait recording: stored landscape, displayed turned clockwise.
    let portrait = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)

    let transform = MediaEditRenderer.rotatedTransform(
      portrait, naturalSize: landscape, quarterTurns: 1)

    #expect(transform == .identity)
  }

  @Test func anUntrimmedVideoKeepsItsWholeLength() {
    let duration = CMTime(value: 900, timescale: 600)

    let kept = MediaEditRenderer.keptTimeRange(nil, duration: duration)

    #expect(kept == CMTimeRange(start: .zero, duration: duration))
  }

  @Test func aTrimKeepsOnlyItsRange() {
    let kept = MediaEditRenderer.keptTimeRange(
      1.5...4, duration: CMTime(value: 6000, timescale: 600))

    #expect(kept.start.seconds == 1.5)
    #expect(kept.end.seconds == 4)
  }

  @Test func aTrimKeepsTheVideosFinerTimescale() {
    let kept = MediaEditRenderer.keptTimeRange(
      0.25...1, duration: CMTime(value: 44_100, timescale: 44_100))

    #expect(kept.start == CMTime(value: 11_025, timescale: 44_100))
  }

  @Test func aQuarterTurnRotatesAnImageCounterclockwise() {
    // Red on the left, blue on the right.
    let red = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    let blue = CIImage(color: .blue).cropped(to: CGRect(x: 1, y: 0, width: 1, height: 1))
    let image = blue.composited(over: red)

    let turned = MediaEditRenderer.rotated(image, quarterTurns: 1)

    #expect(turned.extent == CGRect(x: 0, y: 0, width: 1, height: 2))
    // Core Image's origin is bottom-left, so turning counterclockwise puts red at the bottom.
    #expect(pixel(of: turned, at: CGPoint(x: 0, y: 0)) == [255, 0, 0])
    #expect(pixel(of: turned, at: CGPoint(x: 0, y: 1)) == [0, 0, 255])
  }

  @Test func turningASizeSwapsItOnOddTurnsOnly() {
    let size = CGSize(width: 3, height: 4)

    #expect(size.turned(by: 0) == size)
    #expect(size.turned(by: 1) == CGSize(width: 4, height: 3))
    #expect(size.turned(by: 2) == size)
    #expect(size.turned(by: 3) == CGSize(width: 4, height: 3))
  }

  private func pixel(of image: CIImage, at point: CGPoint) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    context.render(
      image, toBitmap: &rgba, rowBytes: 4,
      bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBA8,
      colorSpace: nil)
    return Array(rgba.prefix(3))
  }
}
