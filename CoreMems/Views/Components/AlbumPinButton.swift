// CoreMems/Views/Components/AlbumPinButton.swift
import SwiftUI

/// Pin/Unpin action for menus and swipe actions.
struct AlbumPinButton: View {
  let isPinned: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
    }
  }
}
