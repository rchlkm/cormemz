// CoreMems/Models/MediaEdit.swift
import CoreGraphics
import Foundation

/// Edits staged for one photo or video, written to the library on Apply.
nonisolated struct MediaEdit: Equatable, Codable {
  /// Counterclockwise quarter turns, 0...3.
  private(set) var quarterTurns = 0
  /// The part of a photo to keep, as fractions of the upright source image from its top-left
  /// corner, before rotation; `nil` keeps all of it.
  private(set) var cropRect: CGRect?
  /// The part of a video to keep, in seconds; `nil` keeps all of it.
  var trimRange: ClosedRange<Double>?
  /// Whether a trimmed video's original is deleted once its trimmed copy is saved.
  var deletesOriginal = true

  var isEmpty: Bool { quarterTurns == 0 && cropRect == nil && trimRange == nil }

  /// Whether rendering has to change a photo's pixels, beyond turning them.
  var changesPixels: Bool { cropRect != nil }

  /// The crop as fractions of the rotated image, which is what the editor shows; setting it
  /// to the whole image clears the crop.
  var displayedCropRect: CGRect {
    get { (cropRect ?? .wholeImage).turned(by: quarterTurns) }
    set {
      let source = newValue.turned(by: -quarterTurns)
      cropRect = source.covers(.wholeImage) ? nil : source
    }
  }

  /// Crops a photo `sourceSize` pixels large to the largest centred area with `aspect`.
  mutating func crop(to aspect: CropAspect, ofSourceSize sourceSize: CGSize) {
    displayedCropRect = aspect.displayedRect(in: sourceSize.turned(by: quarterTurns))
  }

  mutating func rotate() {
    quarterTurns = (quarterTurns + 1) % 4
  }

  /// Keeps `range` of a video `duration` seconds long; keeping all of it clears the trim and
  /// its options.
  mutating func trim(to range: ClosedRange<Double>, ofDuration duration: Double) {
    guard range.lowerBound > 0 || range.upperBound < duration else {
      trimRange = nil
      deletesOriginal = true
      return
    }
    trimRange = range
  }
}

nonisolated extension MediaEdit {
  private enum CodingKeys: String, CodingKey {
    case quarterTurns, cropRect, trimRange, deletesOriginal
  }

  /// Fields are optional so edits saved before a field existed still decode.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    quarterTurns = try container.decodeIfPresent(Int.self, forKey: .quarterTurns) ?? 0
    cropRect = try container.decodeIfPresent(CGRect.self, forKey: .cropRect)
    trimRange = try container.decodeIfPresent(ClosedRange<Double>.self, forKey: .trimRange)
    deletesOriginal = try container.decodeIfPresent(Bool.self, forKey: .deletesOriginal) ?? true
  }
}

nonisolated extension CGRect {
  /// The whole of an image, as fractions of its size.
  static let wholeImage = CGRect(x: 0, y: 0, width: 1, height: 1)

  /// Whether this rect, within a hair, includes all of `other`.
  func covers(_ other: CGRect) -> Bool {
    let tolerance: CGFloat = 1e-4
    return minX <= other.minX + tolerance && minY <= other.minY + tolerance
      && maxX >= other.maxX - tolerance && maxY >= other.maxY - tolerance
  }

  /// Whether this rect and `other` are the same, within a hair.
  func isSame(as other: CGRect) -> Bool { covers(other) && other.covers(self) }

  /// A rect within the whole image, turned counterclockwise by `quarterTurns` quarter turns
  /// along with the image; negative turns go clockwise.
  func turned(by quarterTurns: Int) -> CGRect {
    (0..<((quarterTurns % 4 + 4) % 4)).reduce(self) { rect, _ in
      CGRect(x: rect.minY, y: 1 - rect.maxX, width: rect.height, height: rect.width)
    }
  }
}
