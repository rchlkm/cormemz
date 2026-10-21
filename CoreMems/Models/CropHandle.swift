// CoreMems/Models/CropHandle.swift
import CoreGraphics

/// A grip on the crop box, and how dragging it resizes the box. Boxes are fractions of the
/// displayed image from its top-left corner.
nonisolated enum CropHandle: CaseIterable {
  case topLeading, topTrailing, bottomLeading, bottomTrailing
  case top, bottom, leading, trailing

  /// The smallest a side of the box can be, as a fraction of the image.
  static let minimumSide: CGFloat = 0.1

  /// -1 when the handle moves the box's left edge, 1 its right edge, 0 neither.
  private var xSide: Int {
    switch self {
    case .topLeading, .bottomLeading, .leading: return -1
    case .topTrailing, .bottomTrailing, .trailing: return 1
    case .top, .bottom: return 0
    }
  }

  /// -1 when the handle moves the box's top edge, 1 its bottom edge, 0 neither.
  private var ySide: Int {
    switch self {
    case .topLeading, .topTrailing, .top: return -1
    case .bottomLeading, .bottomTrailing, .bottom: return 1
    case .leading, .trailing: return 0
    }
  }

  var isCorner: Bool { xSide != 0 && ySide != 0 }

  /// The area of `box` this handle grips: a corner, or a whole edge.
  private func grip(on box: CGRect) -> CGRect {
    let x = xSide < 0 ? box.minX : box.maxX
    let y = ySide < 0 ? box.minY : box.maxY
    return CGRect(
      x: xSide == 0 ? box.minX : x, y: ySide == 0 ? box.minY : y,
      width: xSide == 0 ? box.width : 0, height: ySide == 0 ? box.height : 0)
  }

  /// Where the handle sits on `box`: a corner, or the middle of an edge.
  func position(on box: CGRect) -> CGPoint {
    let grip = grip(on: box)
    return CGPoint(x: grip.midX, y: grip.midY)
  }

  /// A mark for the handle on `box`: a corner's two edges, or a segment of an edge, `length`
  /// long.
  func mark(on box: CGRect, length: CGFloat) -> CGPath {
    let at = position(on: box)
    let path = CGMutablePath()
    if isCorner {
      path.move(to: CGPoint(x: at.x - CGFloat(xSide) * length, y: at.y))
      path.addLine(to: at)
      path.addLine(to: CGPoint(x: at.x, y: at.y - CGFloat(ySide) * length))
    } else if xSide == 0 {
      path.move(to: CGPoint(x: at.x - length / 2, y: at.y))
      path.addLine(to: CGPoint(x: at.x + length / 2, y: at.y))
    } else {
      path.move(to: CGPoint(x: at.x, y: at.y - length / 2))
      path.addLine(to: CGPoint(x: at.x, y: at.y + length / 2))
    }
    return path
  }

  /// The handle of `box` that a touch at `point` grabs, preferring a corner; `nil` when
  /// every grip is further than `reach` away. All in the same units.
  static func grabbed(at point: CGPoint, on box: CGRect, reach: CGFloat) -> CropHandle? {
    for group in [allCases.filter(\.isCorner), allCases.filter { !$0.isCorner }] {
      let nearest = group.min { $0.distance(from: point, to: box) < $1.distance(from: point, to: box) }
      if let nearest, nearest.distance(from: point, to: box) <= reach { return nearest }
    }
    return nil
  }

  private func distance(from point: CGPoint, to box: CGRect) -> CGFloat {
    let grip = grip(on: box)
    return hypot(
      max(0, grip.minX - point.x, point.x - grip.maxX),
      max(0, grip.minY - point.y, point.y - grip.maxY))
  }

  /// `box` with this handle moved to `point`, kept inside the image and at least the minimum
  /// side. With `keepingShape` the box keeps its width-to-height ratio, anchored on the
  /// opposite side, and an edge handle grows it about the middle of the other axis.
  func dragged(_ box: CGRect, to point: CGPoint, keepingShape: Bool) -> CGRect {
    keepingShape ? draggedKeepingShape(box, to: point) : draggedFreely(box, to: point)
  }

  private func draggedFreely(_ box: CGRect, to point: CGPoint) -> CGRect {
    let side = Self.minimumSide
    var (minX, maxX, minY, maxY) = (box.minX, box.maxX, box.minY, box.maxY)
    if xSide < 0 { minX = min(max(point.x, 0), maxX - side) }
    if xSide > 0 { maxX = max(min(point.x, 1), minX + side) }
    if ySide < 0 { minY = min(max(point.y, 0), maxY - side) }
    if ySide > 0 { maxY = max(min(point.y, 1), minY + side) }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private func draggedKeepingShape(_ box: CGRect, to point: CGPoint) -> CGRect {
    let ratio = box.width / box.height
    // The fixed side of each axis this handle moves.
    let anchor = CGPoint(x: xSide < 0 ? box.maxX : box.minX, y: ySide < 0 ? box.maxY : box.minY)

    let wanted = max(
      xSide == 0 ? 0 : abs(point.x - anchor.x),
      ySide == 0 ? 0 : abs(point.y - anchor.y) * ratio)
    let roomX = xSide == 0 ? 2 * min(box.midX, 1 - box.midX) : (xSide < 0 ? anchor.x : 1 - anchor.x)
    let roomY = ySide == 0 ? 2 * min(box.midY, 1 - box.midY) : (ySide < 0 ? anchor.y : 1 - anchor.y)
    let smallest = Self.minimumSide * max(1, ratio)
    let width = min(max(wanted, smallest), min(roomX, roomY * ratio))
    let height = width / ratio

    return CGRect(
      x: xSide == 0 ? box.midX - width / 2 : (xSide < 0 ? anchor.x - width : anchor.x),
      y: ySide == 0 ? box.midY - height / 2 : (ySide < 0 ? anchor.y - height : anchor.y),
      width: width, height: height)
  }
}
