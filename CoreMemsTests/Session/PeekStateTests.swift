// CoreMemsTests/Session/PeekStateTests.swift
import Testing

@testable import CoreMems

@Suite("Peek state")
struct PeekStateTests {
  private func loaded(anchor: String = "c", ids: [String] = ["a", "b", "c", "d", "e"]) -> PeekState {
    var state = PeekState(anchorID: anchor)
    state.finishLoading(neighborIDs: ids)
    return state
  }

  @Test func startsFocusedOnTheAnchorAndLoading() {
    let state = PeekState(anchorID: "c")

    #expect(state.focusedID == "c")
    #expect(state.isLoading)
    #expect(state.neighborIDs.isEmpty)
  }

  @Test func aFullWindowCanGrowOnBothSides() {
    let state = loaded()

    #expect(state.canLoadOlder)
    #expect(state.canLoadNewer)
    #expect(!state.isLoading)
  }

  @Test func aTruncatedSideCannotGrow() {
    let state = loaded(anchor: "a", ids: ["a", "b", "c"])

    #expect(!state.canLoadOlder)
    #expect(state.canLoadNewer)
  }

  @Test func wideningStopsAtTheCap() {
    var state = PeekState(anchorID: "6")
    while state.olderCount < PeekState.maxCount {
      state.widen(.older)
    }
    state.finishLoading(neighborIDs: (0..<13).map(String.init))

    #expect(state.olderCount == PeekState.maxCount)
    #expect(!state.canLoadOlder)
  }

  @Test func wideningMarksTheSideLoadingUntilTheWindowArrives() {
    var state = loaded()

    state.widen(.newer)
    #expect(state.loadingSide == .newer)
    #expect(state.isLoading)
    #expect(!state.canLoadNewer)

    state.finishLoading(neighborIDs: ["a", "b", "c", "d", "e", "f", "g"])
    #expect(state.loadingSide == nil)
    #expect(!state.isLoading)
  }

  @Test func onlyPhotosNearAnEndAskForMore() {
    let state = loaded(ids: ["a", "b", "c", "d", "e", "f", "g"])

    #expect(state.edgeSides(of: "a") == [.older])
    #expect(state.edgeSides(of: "b") == [.older])
    #expect(state.edgeSides(of: "d").isEmpty)
    #expect(state.edgeSides(of: "g") == [.newer])
  }

  @Test func aStaleWindowIsRecognized() {
    var state = loaded()
    state.widen(.older)

    #expect(state.isCurrentWindow(older: 4, newer: 2))
    #expect(!state.isCurrentWindow(older: 2, newer: 2))
  }
}
