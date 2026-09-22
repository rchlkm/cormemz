// CoreMems/Views/Components/SelectionColors.swift
// Replaces the color-helper half of Styles.swift. These are
// selection-state color tokens (used inside CardButtonStyle-driven
// rows like SetupView's option list), not components themselves —
// kept separate from Buttons.swift on purpose.
import SwiftUI
import UIKit

func secondaryTextColor(isSelected: Bool) -> Color {
  Color(
    uiColor: UIColor { traitCollection in
      let isDark = traitCollection.userInterfaceStyle == .dark
      if isSelected {
        return isDark
          ? UIColor.black.withAlphaComponent(0.7)
          : UIColor.white.withAlphaComponent(0.7)
      }
      return UIColor.secondaryLabel
    })
}