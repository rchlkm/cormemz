// CoreMemsTests/Session/CropHandleTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Crop handles")
struct CropHandleTests {
  private let box = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.4)
  private let side = CropHandle.minimumSide

  private func expectSame(_ rect: CGRect, _ expected: CGRect) {
    #expect(rect.isSame(as: expected), "\(rect) is not \(expected)")
  }

  // MARK: Free resizing

  @Test func aCornerMovesTwoEdges() {
    let rect = CropHandle.topLeading.dragged(
      box, to: CGPoint(x: 0.1, y: 0.3), keepingShape: false)

    expectSame(rect, CGRect(x: 0.1, y: 0.3, width: 0.7, height: 0.3))
  }

  @Test func anEdgeMovesOneEdge() {
    let rect = CropHandle.trailing.dragged(box, to: CGPoint(x: 0.9, y: 0), keepingShape: false)

    expectSame(rect, CGRect(x: 0.2, y: 0.2, width: 0.7, height: 0.4))
  }

  @Test func aBoxStaysInsideTheImage() {
    let rect = CropHandle.bottomTrailing.dragged(
      box, to: CGPoint(x: 1.5, y: -3), keepingShape: false)
    let top = CropHandle.topLeading.dragged(box, to: CGPoint(x: -1, y: -1), keepingShape: false)

    expectSame(rect, CGRect(x: 0.2, y: 0.2, width: 0.8, height: side))
    expectSame(top, CGRect(x: 0, y: 0, width: 0.8, height: 0.6))
  }

  @Test func aBoxKeepsTheMinimumSide() {
    let rect = CropHandle.topLeading.dragged(box, to: CGPoint(x: 5, y: 5), keepingShape: false)

    expectSame(rect, CGRect(x: 0.8 - side, y: 0.6 - side, width: side, height: side))
  }

  // MARK: Keeping the shape

  @Test func aCornerKeepsTheRatioAndAnchorsTheOppositeCorner() {
    let rect = CropHandle.bottomTrailing.dragged(
      box, to: CGPoint(x: 0.6, y: 0.5), keepingShape: true)

    // Wider than it is tall by the same 3:2, from the top-left corner.
    expectSame(rect, CGRect(x: 0.2, y: 0.2, width: 0.45, height: 0.3))
  }

  @Test func aCornerFollowsTheFartherOfTheTwoAxes() {
    let rect = CropHandle.bottomTrailing.dragged(
      box, to: CGPoint(x: 0.5, y: 0.7), keepingShape: true)

    expectSame(rect, CGRect(x: 0.2, y: 0.2, width: 0.75, height: 0.5))
  }

  @Test func aShapeKeepingBoxStopsAtTheImageEdge() {
    let rect = CropHandle.bottomTrailing.dragged(
      box, to: CGPoint(x: 3, y: 3), keepingShape: true)

    // The right edge allows 0.8 width but the bottom only allows 0.8 height, 1.2 wide.
    expectSame(rect, CGRect(x: 0.2, y: 0.2, width: 0.8, height: 0.8 / 1.5))
  }

  @Test func aShapeKeepingBoxKeepsItsMinimumSides() {
    let tall = CGRect(x: 0.3, y: 0.1, width: 0.2, height: 0.8)

    let rect = CropHandle.bottomTrailing.dragged(
      tall, to: CGPoint(x: 0.3, y: 0.1), keepingShape: true)

    expectSame(rect, CGRect(x: 0.3, y: 0.1, width: side, height: side * 4))
  }

  @Test func anEdgeKeepingTheShapeGrowsAboutTheOtherAxisMiddle() {
    let rect = CropHandle.trailing.dragged(
      box, to: CGPoint(x: 0.6, y: 0), keepingShape: true)

    // 0.4 wide from the left edge, so 0.4 / 1.5 tall around the middle (y 0.4).
    expectSame(rect, CGRect(x: 0.2, y: 0.4 - 0.4 / 3, width: 0.4, height: 0.4 / 1.5))
  }

  @Test func aTopEdgeKeepingTheShapeGrowsSideways() {
    let rect = CropHandle.top.dragged(box, to: CGPoint(x: 0, y: 0.1), keepingShape: true)

    // 0.5 tall down to the bottom edge, so 0.75 wide around the middle (x 0.5).
    expectSame(rect, CGRect(x: 0.125, y: 0.1, width: 0.75, height: 0.5))
  }

  @Test func anEdgeKeepingTheShapeStopsWhereTheOtherAxisRunsOut() {
    let nearTheTop = CGRect(x: 0.2, y: 0.05, width: 0.6, height: 0.4)

    let rect = CropHandle.trailing.dragged(
      nearTheTop, to: CGPoint(x: 1, y: 0), keepingShape: true)

    // The box is centred on y 0.25, so it can be at most 0.5 tall and 0.75 wide.
    expectSame(rect, CGRect(x: 0.2, y: 0, width: 0.75, height: 0.5))
  }

  @Test func theShapeIsKeptThroughAnyDrag() {
    let ratio = box.width / box.height
    for handle in CropHandle.allCases {
      for point in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.95, y: 0.1), CGPoint(x: 0.05, y: 0.9)] {
        let rect = handle.dragged(box, to: point, keepingShape: true)

        #expect(abs(rect.width / rect.height - ratio) < 1e-9)
        #expect(CGRect.wholeImage.covers(rect))
      }
    }
  }

  // MARK: Grabbing

  @Test func aTouchNearACornerGrabsIt() {
    let frame = CGRect(x: 100, y: 100, width: 200, height: 300)

    #expect(
      CropHandle.grabbed(at: CGPoint(x: 290, y: 110), on: frame, reach: 30) == .topTrailing)
    #expect(
      CropHandle.grabbed(at: CGPoint(x: 90, y: 410), on: frame, reach: 30) == .bottomLeading)
  }

  @Test func aTouchAlongAnEdgeGrabsIt() {
    let frame = CGRect(x: 100, y: 100, width: 200, height: 300)

    #expect(CropHandle.grabbed(at: CGPoint(x: 200, y: 105), on: frame, reach: 30) == .top)
    #expect(CropHandle.grabbed(at: CGPoint(x: 295, y: 250), on: frame, reach: 30) == .trailing)
  }

  @Test func aCornerWinsOverAnEdgeWhereTheyOverlap() {
    let frame = CGRect(x: 100, y: 100, width: 200, height: 300)

    #expect(
      CropHandle.grabbed(at: CGPoint(x: 120, y: 100), on: frame, reach: 30) == .topLeading)
  }

  @Test func aTouchAwayFromTheBoxGrabsNothing() {
    let frame = CGRect(x: 100, y: 100, width: 200, height: 300)

    #expect(CropHandle.grabbed(at: CGPoint(x: 200, y: 250), on: frame, reach: 30) == nil)
    #expect(CropHandle.grabbed(at: CGPoint(x: 10, y: 10), on: frame, reach: 30) == nil)
  }

  @Test func aHandleSitsOnItsCornerOrEdgeMiddle() {
    for (handle, x, y) in [
      (CropHandle.bottomTrailing, 0.8, 0.6), (.top, 0.5, 0.2), (.leading, 0.2, 0.4),
    ] {
      let position = handle.position(on: box)

      #expect(abs(position.x - x) < 1e-9 && abs(position.y - y) < 1e-9)
    }
  }
}
