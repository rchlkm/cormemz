// CoreMems/Views/Styles/GlassStyle.swift
import SwiftUI

extension View {
  /// The frosted surface for chrome drawn over photos. Interactive glass reacts to touches.
  func frostedGlass<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
    glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
  }
}
