// CoreMems/Views/Components/DeletionTrayButton.swift
import SwiftUI

/// Small badge button showing how many photos are currently marked
/// for deletion; opens the Deletion Tray when tapped.
struct DeletionTrayButton: View {
  let pendingCount: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        Image(systemName: "tray.full")
          .frame(width: 34, height: 34)
          .background(.thinMaterial, in: Circle())
          .foregroundStyle(pendingCount == 0 ? Color.secondary : Color.blue)

        if pendingCount > 0 {
          Text("\(pendingCount)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.blue, in: Circle())
            .offset(x: 4, y: -4)
        }
      }
    }
  }
}
