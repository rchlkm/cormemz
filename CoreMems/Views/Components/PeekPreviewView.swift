// CoreMems/Views/Components/PeekPreviewView.swift
import SwiftUI

/// Full-size image of the focused neighbor, laid over the browse card's own photo. The
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
        AdaptiveAssetImage(photo: neighbor, fitWithin: maxSize, showsLowQualityFirst: true)
          // TODO: Show the neighbor's MediaKind symbol instead of the generic video icon.
          .overlay { if neighbor.isVideo { PeekVideoIcon() } }
          .opacity(neighbor.id == focusedID ? 1 : 0)
      }
    }
    .opacity(isVisible ? 1 : 0)
    .allowsHitTesting(false)
  }
}

/// Centered icon on a video's still, which plays only once opened full screen.
private struct PeekVideoIcon: View {
  var body: some View {
    Image(systemName: "video.fill")
      .font(.system(size: 26, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 64, height: 64)
      .background(.black.opacity(0.6), in: Circle())
  }
}

/// Names a photo's decision, so a marked neighbor reads as marked; a photo with an edit
/// to write reads as edited, whatever it was decided.
struct PeekDecisionTag: View {
  let decision: Decision
  var isEdited = false

  private var content: (icon: String, title: String, tint: Color)? {
    if isEdited { return (EditStyle.symbol, EditStyle.title, EditStyle.tint) }
    return decision == .undecided ? nil : DecisionOverlay.content(for: decision)
  }

  var body: some View {
    if let content {
      Label(content.title, systemImage: content.icon)
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(content.tint.opacity(0.55), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }
  }
}
