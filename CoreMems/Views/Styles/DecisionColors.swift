// CoreMems/Views/Styles/DecisionColors.swift
import SwiftUI

extension ReviewDecision {
  /// The one color for each outcome, used by review, tray, and stats screens.
  var tint: Color {
    switch self {
    case .keep: return .green
    case .pendingDelete: return .red
    case .convertToStill: return .blue
    case .undecided: return .secondary
    }
  }
}
