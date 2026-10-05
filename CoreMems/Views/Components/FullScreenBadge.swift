// CoreMems/Views/Components/FullScreenBadge.swift
import SwiftUI

extension View {
  /// Dark capsule matching Photos' full-screen "LIVE" and "SLO-MO" badges.
  func fullScreenBadgeStyle() -> some View {
    self
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Capsule().fill(.black.opacity(0.55)))
  }
}

/// Names what sets a photo or video apart, such as slo-mo, on its full-screen view.
struct MediaKindBadge: View {
  let kind: MediaKind

  var body: some View {
    Label(kind.title, systemImage: kind.symbol)
      .fullScreenBadgeStyle()
  }
}
