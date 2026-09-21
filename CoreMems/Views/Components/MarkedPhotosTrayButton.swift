// CoreMems/Views/Components/MarkedPhotosTrayButton.swift
import SwiftUI

/// Small badge button showing how many photos are currently marked for
/// deletion or conversion; opens the marked-photos tray when tapped.
struct MarkedPhotosTrayButton: View {
  let markedCount: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "tray.full")
    }
    .buttonStyle(
      IconButtonStyle(
        size: .small, surface: .material(markedCount == 0 ? Color.secondary : Color.blue))
    )
    .overlay(alignment: .topTrailing) {
      if markedCount > 0 {
        Text("\(markedCount)")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white)
          .padding(4)
          .background(Color.blue, in: Circle())
          .offset(x: 4, y: -4)
          .allowsHitTesting(false)
      }
    }
  }
}
