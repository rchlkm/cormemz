// CoreMems/Views/Components/Buttons.swift
import SwiftUI


/// Round icon button used for the keep/delete/undo review controls
/// and anywhere else a simple tinted circular action fits.
struct CircleIconButton: View {
  let system: String
  let tint: Color
  let size: CGFloat
  var disabled: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: size * 0.34, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background(tint.opacity(0.16), in: Circle())
    }
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
  }
}
