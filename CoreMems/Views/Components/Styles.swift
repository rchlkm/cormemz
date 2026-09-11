import SwiftUI
import UIKit

struct CardButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  let isSelected: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(16)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
      .foregroundColor(primaryTextColor)
      .opacity(configuration.isPressed ? 0.85 : 1.0)
      .animation(.snappy(duration: 0.2), value: isSelected)
  }

  private var cardBackground: Color {
    if isSelected {
      return colorScheme == .dark ? .white : .black
    }
    return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : .white
  }

  private var primaryTextColor: Color {
    isSelected ? (colorScheme == .dark ? .black : .white) : .primary
  }
}

struct PrimaryActionButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .semibold))
      .foregroundColor(colorScheme == .dark ? .black : .white)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        colorScheme == .dark ? Color.white : Color.black,
        in: RoundedRectangle(cornerRadius: 16)
      )
      .opacity(configuration.isPressed ? 0.85 : 1.0)
  }
}

public func innerBoxColor(isSelected: Bool) -> Color {
  Color(
    uiColor: UIColor { traitCollection in
      let isDark = traitCollection.userInterfaceStyle == .dark
      if isSelected {
        return isDark
          ? UIColor.black.withAlphaComponent(0.15)
          : UIColor.white.withAlphaComponent(0.2)
      }
      return isDark
        ? UIColor.white.withAlphaComponent(0.1)
        : UIColor.black.withAlphaComponent(0.06)
    })
}

public func secondaryTextColor(isSelected: Bool) -> Color {
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
