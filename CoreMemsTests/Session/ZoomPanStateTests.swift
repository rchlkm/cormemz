// CoreMemsTests/Session/ZoomPanStateTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Zoom and pan state")
struct ZoomPanStateTests {
  @Test func startsAtRest() {
    let state = ZoomPanState()

    #expect(state.scale == 1)
    #expect(!state.isZoomed)
    #expect(state.offset == .zero)
    #expect(state.backgroundOpacity == 1)
    #expect(state.chromeOpacity == 1)
  }

  @Test func pinchingScalesFromTheScaleAtTheStartOfThePinch() {
    var state = ZoomPanState()
    state.pinch(by: 2)
    state.endPinch()

    state.pinch(by: 1.5)

    #expect(state.scale == 3)
  }

  @Test func pinchingIsClampedBetweenOneAndTheMaximum() {
    var state = ZoomPanState()

    state.pinch(by: 0.2)
    #expect(state.scale == 1)

    state.pinch(by: 100)
    #expect(state.scale == ZoomPanState.maxScale)
  }

  @Test func aPinchEndingNearOneXIsNearRest() {
    var state = ZoomPanState()
    state.pinch(by: 1.04)
    #expect(state.isNearRest)

    state.pinch(by: 1.5)
    #expect(!state.isNearRest)
  }

  @Test func draggingWhileZoomedPansAndAccumulatesAcrossDrags() {
    var state = ZoomPanState()
    state.pinch(by: 2)
    state.drag(by: CGSize(width: 30, height: -10))
    _ = state.endDrag(translation: CGSize(width: 30, height: -10))

    state.drag(by: CGSize(width: 5, height: 5))

    #expect(state.panOffset == CGSize(width: 35, height: -5))
    #expect(state.dismissDrag == .zero)
  }

  @Test func draggingAtOneXMovesThePhotoAndFadesTheBackdrop() {
    var state = ZoomPanState()

    state.drag(by: CGSize(width: 0, height: 200))

    #expect(state.offset == CGSize(width: 0, height: 200))
    #expect(state.backgroundOpacity == 0.5)
    #expect(state.chromeOpacity == 0.5)
  }

  @Test func aLongDragAtOneXDismisses() {
    var state = ZoomPanState()
    let translation = CGSize(width: 90, height: 90)
    state.drag(by: translation)

    let dismissed = state.endDrag(translation: translation)

    #expect(dismissed)
  }

  @Test func aShortDragAtOneXDoesNotDismissAndSpringsBack() {
    var state = ZoomPanState()
    let translation = CGSize(width: 40, height: 40)
    state.drag(by: translation)

    let dismissed = state.endDrag(translation: translation)
    state.cancelDismissDrag()

    #expect(!dismissed)
    #expect(state.offset == .zero)
  }

  @Test func zoomingHidesChromeAndKeepsTheBackdropSolid() {
    var state = ZoomPanState()
    state.pinch(by: 2)

    #expect(state.isZoomed)
    #expect(state.backgroundOpacity == 1)
    #expect(state.chromeOpacity == 0)
  }

  @Test func togglingZoomAlternatesBetweenDoubleTapScaleAndRest() {
    var state = ZoomPanState()

    state.toggleZoom()
    #expect(state.scale == ZoomPanState.doubleTapScale)

    state.toggleZoom()
    #expect(state.scale == 1)
    #expect(state.panOffset == .zero)
  }

  @Test func resettingReturnsToRestWithFreshGestureBaselines() {
    var state = ZoomPanState()
    state.toggleZoom()
    state.drag(by: CGSize(width: 50, height: 50))
    _ = state.endDrag(translation: CGSize(width: 50, height: 50))

    state.reset()
    state.pinch(by: 2)
    state.drag(by: CGSize(width: 1, height: 1))

    #expect(state.scale == 2)
    #expect(state.panOffset == CGSize(width: 1, height: 1))
  }
}
