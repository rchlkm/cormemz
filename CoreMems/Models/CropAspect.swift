// CoreMems/Models/CropAspect.swift
import CoreGraphics

/// A shape a photo can be cropped to, matched to the photo's orientation.
nonisolated enum CropAspect: CaseIterable, Identifiable {
  case original, square, fourThree, threeTwo, sixteenNine

  var id: Self { self }

  var title: String {
    switch self {
    case .original: return "Original"
    case .square: return "Square"
    case .fourThree: return "4:3"
    case .threeTwo: return "3:2"
    case .sixteenNine: return "16:9"
    }
  }

  /// Long side over short side; `nil` keeps the photo's own shape.
  private var elongation: CGFloat? {
    switch self {
    case .original: return nil
    case .square: return 1
    case .fourThree: return 4.0 / 3
    case .threeTwo: return 3.0 / 2
    case .sixteenNine: return 16.0 / 9
    }
  }

  /// The largest centred area of an image `size` pixels large with this shape, as fractions
  /// of the image. It is wide for a landscape image and tall for a portrait one.
  func displayedRect(in size: CGSize) -> CGRect {
    guard let elongation, size.width > 0, size.height > 0 else { return .wholeImage }
    let aspect = size.width >= size.height ? elongation : 1 / elongation
    let width = min(1, aspect * size.height / size.width)
    let height = min(1, size.width / aspect / size.height)
    return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
  }

  /// The shape `edit` crops a photo `sourceSize` pixels large to, if it is one of these.
  static func matching(_ edit: MediaEdit, sourceSize: CGSize) -> CropAspect? {
    let displayed = edit.displayedCropRect
    let size = sourceSize.turned(by: edit.quarterTurns)
    return allCases.first { displayed.isSame(as: $0.displayedRect(in: size)) }
  }
}
