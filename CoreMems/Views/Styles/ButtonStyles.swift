// CoreMems/Views/Components/Buttons.swift
import SwiftUI

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
      .padding(.horizontal, 32)
      .padding(.bottom, 26)
  }
}

struct DestructiveActionButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .semibold))
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
      .opacity(configuration.isPressed ? 0.85 : 1.0)
  }
}

struct SecondaryActionButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .semibold))
      .foregroundColor(colorScheme == .dark ? .white : .black)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        Color.secondary.opacity(colorScheme == .dark ? 0.22 : 0.10),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .opacity(configuration.isPressed ? 0.8 : 1.0)
  }
}
