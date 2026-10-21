// CoreMems/Views/Components/CropOverlay.swift
import SwiftUI

/// The crop box over a photo shown whole: the part outside it dimmed, a thirds grid inside,
/// and grips on its corners and edges that resize it. It fills the frame the photo is fitted
/// in and sets the edit's displayed crop. A box whose aspect locks its shape keeps that shape
/// while resized.
struct CropOverlay: View {
  @Binding var edit: MediaEdit
  @Binding var aspect: CropAspect
  /// The pixel size of the photo before rotation.
  let sourceSize: CGSize

  /// The grip being dragged and the box it started from.
  private struct Grab {
    let handle: CropHandle
    let box: CGRect
    let keepsShape: Bool
  }

  @State private var grab: Grab?

  private static let reach: CGFloat = 32
  private static let markLength: CGFloat = 22
  private static let thirds: [CGFloat] = [1.0 / 3, 2.0 / 3]
  private static let dim = Color.black.opacity(0.55)

  var body: some View {
    GeometryReader { proxy in
      let area = photoArea(in: proxy.size)
      Canvas { context, _ in
        draw(edit.displayedCropRect.scaled(to: area.size), in: area.size, with: context)
      }
      .frame(width: area.width, height: area.height)
      .position(x: area.midX, y: area.midY)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(resize(in: area))
    }
    .accessibilityElement()
    .accessibilityLabel("Crop box")
  }

  /// Where the photo, fitted whole, sits in `frame`.
  private func photoArea(in frame: CGSize) -> CGRect {
    let shown = sourceSize.turned(by: edit.quarterTurns)
    guard shown.width > 0, shown.height > 0 else { return CGRect(origin: .zero, size: frame) }
    let scale = min(frame.width / shown.width, frame.height / shown.height)
    let size = CGSize(width: shown.width * scale, height: shown.height * scale)
    return CGRect(
      x: (frame.width - size.width) / 2, y: (frame.height - size.height) / 2,
      width: size.width, height: size.height)
  }

  private func draw(_ frame: CGRect, in size: CGSize, with context: GraphicsContext) {
    var outside = Path(CGRect(origin: .zero, size: size))
    outside.addRect(frame)
    context.fill(outside, with: .color(Self.dim), style: FillStyle(eoFill: true))

    var grid = Path()
    for fraction in Self.thirds {
      grid.move(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY))
      grid.addLine(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY))
      grid.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction))
      grid.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction))
    }
    context.stroke(grid, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
    context.stroke(Path(frame), with: .color(.white), lineWidth: 1)

    for handle in CropHandle.allCases {
      context.stroke(
        Path(handle.mark(on: frame, length: Self.markLength)), with: .color(.white),
        style: StrokeStyle(lineWidth: 3, lineCap: .square))
    }
  }

  private func resize(in area: CGRect) -> some Gesture {
    let size = area.size
    return DragGesture(minimumDistance: 0)
      .onChanged { value in
        if grab == nil {
          let box = edit.displayedCropRect
          let start = CGPoint(
            x: value.startLocation.x - area.minX, y: value.startLocation.y - area.minY)
          guard
            let handle = CropHandle.grabbed(at: start, on: box.scaled(to: size), reach: Self.reach)
          else { return }
          grab = Grab(handle: handle, box: box, keepsShape: aspect.locksShape)
        }
        guard let grab else { return }
        let start = grab.handle.position(on: grab.box)
        let point = CGPoint(
          x: start.x + value.translation.width / size.width,
          y: start.y + value.translation.height / size.height)
        edit.displayedCropRect = grab.handle.dragged(
          grab.box, to: point, keepingShape: grab.keepsShape)
      }
      .onEnded { _ in
        if let grab, !grab.keepsShape {
          aspect = CropAspect.matching(edit, sourceSize: sourceSize)
        }
        grab = nil
      }
  }
}

private extension CGRect {
  /// A rect given as fractions of a size, in that size's units.
  func scaled(to size: CGSize) -> CGRect {
    CGRect(
      x: minX * size.width, y: minY * size.height, width: width * size.width,
      height: height * size.height)
  }
}
