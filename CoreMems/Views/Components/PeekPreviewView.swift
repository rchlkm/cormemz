// CoreMems/Views/Components/PeekPreviewView.swift
import SwiftUI

/// Full-size image of the focused neighbor, laid over the review card's own photo. The
/// focused photo and the ones beside it stay mounted, so stepping to an adjacent photo
/// shows its image at once.
struct PeekPreviewView: View {
  let neighbors: [SessionPhoto]
  let focusedID: String
  let maxSize: CGSize
  let isVisible: Bool

  /// How many neighbors on each side of the focused one keep their full image loaded.
  private static let reach = 1

  private var mounted: [SessionPhoto] {
    let focusedIndex = neighbors.firstIndex { $0.id == focusedID } ?? 0
    return neighbors.indices
      .filter { abs($0 - focusedIndex) <= Self.reach }
      .map { neighbors[$0] }
  }

  var body: some View {
    ZStack {
      Color.black
      ForEach(mounted) { neighbor in
        AdaptiveAssetImage(photo: neighbor, fitWithin: maxSize)
          .opacity(neighbor.id == focusedID ? 1 : 0)
      }
    }
    .opacity(isVisible ? 1 : 0)
    .allowsHitTesting(false)
  }
}

/// Names a photo's decision, so a marked neighbor reads as marked.
struct PeekDecisionTag: View {
  let decision: ReviewDecision

  var body: some View {
    if decision != .undecided {
      let content = DecisionOverlay.content(for: decision)
      Label(content.title, systemImage: content.icon)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(content.tint.opacity(0.85), in: Capsule())
    }
  }
}
