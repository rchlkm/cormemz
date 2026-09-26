// CoreMems/Views/Components/ReviewCardBadges.swift
import SwiftUI

/// Sits behind the review card and fades in as the card is dragged up, hinting at the
/// nearby-photos gesture. `progress` runs 0...1.
struct SwipeUpHintView: View {
  let size: CGSize
  let progress: Double

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 26)
        .fill(Color.black.opacity(0.6))
      VStack {
        Spacer()
        VStack(spacing: 4) {
          Image(systemName: "chevron.up")
            .font(.system(size: 16, weight: .bold))
          Text("Nearby photos")
            .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.bottom, 32)
      }
    }
    .frame(width: size.width, height: size.height)
    .opacity(progress)
  }
}
