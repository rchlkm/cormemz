// CoreMems/Views/Components/QuarterTurnRotation.swift
import SwiftUI

extension View {
  /// Turns the view counterclockwise by `quarterTurns` quarter turns and lays it out at its
  /// turned size, so a sideways turn fits the space it's given.
  func rotated(quarterTurns: Int) -> some View {
    QuarterTurnLayout(quarterTurns: quarterTurns) {
      rotationEffect(.degrees(-90 * Double(quarterTurns)))
    }
  }
}

extension CGSize {
  /// The size after `quarterTurns` quarter turns: width and height swap on odd turns.
  func turned(by quarterTurns: Int) -> CGSize {
    quarterTurns.isMultiple(of: 2) ? self : CGSize(width: height, height: width)
  }
}

extension SessionPhoto {
  /// Quarter turns the photo is shown with, matching what confirming the session writes.
  var previewQuarterTurns: Int { activeEdit?.quarterTurns ?? 0 }
}

/// Offers its child the turned space and reports the child's size turned back.
private struct QuarterTurnLayout: Layout {
  let quarterTurns: Int

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let child = subviews.first else { return .zero }
    return child.sizeThatFits(turned(proposal)).turned(by: quarterTurns)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    subviews.first?.place(
      at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
      proposal: ProposedViewSize(bounds.size.turned(by: quarterTurns)))
  }

  private func turned(_ proposal: ProposedViewSize) -> ProposedViewSize {
    quarterTurns.isMultiple(of: 2)
      ? proposal : ProposedViewSize(width: proposal.height, height: proposal.width)
  }
}
