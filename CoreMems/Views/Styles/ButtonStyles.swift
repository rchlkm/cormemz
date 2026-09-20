// CoreMems/Views/Styles/ButtonStyles.swift
import SwiftUI

/// Shared sizing and state tokens for every button style.
enum ButtonMetrics {
  static let cornerRadius: CGFloat = 16
  static let actionHeight: CGFloat = 56
  static let chipHorizontalPadding: CGFloat = 12
  static let chipVerticalPadding: CGFloat = 8
  static let pressedOpacity: Double = 0.85
  static let disabledOpacity: Double = 0.4

  static func opacity(isPressed: Bool, isEnabled: Bool) -> Double {
    guard isEnabled else { return disabledOpacity }
    return isPressed ? pressedOpacity : 1
  }
}

enum ActionButtonRole {
  case primary
  case secondary
  case destructive

  fileprivate func foreground(in scheme: ColorScheme) -> Color {
    switch self {
    case .primary: return scheme == .dark ? .black : .white
    case .secondary: return scheme == .dark ? .white : .black
    case .destructive: return .white
    }
  }

  fileprivate func background(in scheme: ColorScheme) -> Color {
    switch self {
    case .primary: return scheme == .dark ? .white : .black
    case .secondary: return Color.secondary.opacity(scheme == .dark ? 0.22 : 0.10)
    case .destructive: return .red
    }
  }
}

/// Full-width text button for a screen's or dialog's main actions.
struct ActionButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled
  let role: ActionButtonRole

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .semibold))
      .foregroundColor(role.foreground(in: colorScheme))
      .frame(maxWidth: .infinity)
      .frame(height: ButtonMetrics.actionHeight)
      .background(
        role.background(in: colorScheme),
        in: RoundedRectangle(cornerRadius: ButtonMetrics.cornerRadius)
      )
      .opacity(ButtonMetrics.opacity(isPressed: configuration.isPressed, isEnabled: isEnabled))
  }
}

/// Selectable option tile that inverts its colors when selected.
struct CardButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled
  let isSelected: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(16)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: ButtonMetrics.cornerRadius))
      .foregroundColor(primaryTextColor)
      .opacity(ButtonMetrics.opacity(isPressed: configuration.isPressed, isEnabled: isEnabled))
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

/// Capsule pill for compact, toggleable choices such as album chips.
struct ChipButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  var isSelected: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.footnote.weight(.medium))
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .padding(.horizontal, ButtonMetrics.chipHorizontalPadding)
      .padding(.vertical, ButtonMetrics.chipVerticalPadding)
      .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
      .opacity(ButtonMetrics.opacity(isPressed: configuration.isPressed, isEnabled: isEnabled))
  }
}

/// Unboxed footnote-sized button for secondary, in-flow actions.
struct InlineButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  var tint: Color = .secondary

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.footnote.weight(.semibold))
      .foregroundStyle(tint)
      .opacity(ButtonMetrics.opacity(isPressed: configuration.isPressed, isEnabled: isEnabled))
  }
}
