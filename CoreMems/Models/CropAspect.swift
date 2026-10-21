// CoreMems/Models/CropAspect.swift
import CoreGraphics

/// A shape a photo can be cropped to, matched to the photo's orientation. `free` is any
/// other shape.
nonisolated enum CropAspect: CaseIterable, Identifiable {
  case original, free, square, fourThree, threeTwo, sixteenNine

  var id: Self { self }

  var title: String {
    switch self {
    case .original: return "Original"
    case .free: return "Free"
    case .square: return "Square"
    case .fourThree: return "4:3"
    case .threeTwo: return "3:2"
    case .sixteenNine: return "16:9"
    }
  }

  /// Long side over short side; `nil` keeps the photo's own shape.
  private var elongation: CGFloat? {
    switch self {
    case .original, .free: return nil
    case .square: return 1
    case .fourThree: return 4.0 / 3
    case .threeTwo: return 3.0 / 2
    case .sixteenNine: return 16.0 / 9
    }
  }

  /// Whether a box of this shape keeps its shape while it is resized.
  var locksShape: Bool { elongation != nil }

  /// The largest centred area of an image `size` pixels large with this shape, as fractions
  /// of the image. It is wide for a landscape image and tall for a portrait one. `nil` for
  /// `free`, which has no shape of its own.
  func displayedRect(in size: CGSize) -> CGRect? {
    guard self != .free else { return nil }
    guard let elongation, size.width > 0, size.height > 0 else { return .wholeImage }
    let aspect = size.width >= size.height ? elongation : 1 / elongation
    let width = min(1, aspect * size.height / size.width)
    let height = min(1, size.width / aspect / size.height)
    return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
  }

  /// The shape `edit` crops a photo `sourceSize` pixels large to: the preset it matches, or
  /// `free`.
  static func matching(_ edit: MediaEdit, sourceSize: CGSize) -> CropAspect {
    let displayed = edit.displayedCropRect
    let size = sourceSize.turned(by: edit.quarterTurns)
    return allCases.first { $0.displayedRect(in: size)?.isSame(as: displayed) == true } ?? .free
  }
}
