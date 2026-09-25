// CoreMems/Views/Components/DecisionOverlay.swift
import SwiftUI

/// Dims the photo and names a decision or swipe action, with the same colored circle
/// as the control bar's buttons; swallows taps.
struct DecisionOverlay: View {
  let icon: String
  let title: String
  let tint: Color

  init(icon: String, title: String, tint: Color) {
    self.icon = icon
    self.title = title
    self.tint = tint
  }

  init(decision: ReviewDecision) {
    let content = Self.content(for: decision)
    self.init(icon: content.icon, title: content.title, tint: content.tint)
  }

  static func content(for decision: ReviewDecision) -> (icon: String, title: String, tint: Color) {
    switch decision {
    case .keep: return ("checkmark", "Kept", decision.tint)
    case .pendingDelete: return ("trash", "Marked for deletion", decision.tint)
    case .convertToStill: return ("livephoto.slash", "Marked for conversion", decision.tint)
    case .undecided: return ("questionmark", "Undecided", decision.tint)
    }
  }

  static var goBack: DecisionOverlay {
    DecisionOverlay(icon: "arrow.uturn.backward", title: "Go back", tint: .secondary)
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.6)
      VStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 64, height: 64)
          .background(Circle().fill(tint.opacity(0.25)))
        Text(title)
          .font(.headline)
          .foregroundStyle(.white)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {}
  }
}
