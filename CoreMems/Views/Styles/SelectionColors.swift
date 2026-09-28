// CoreMems/Views/Components/SelectionColors.swift
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