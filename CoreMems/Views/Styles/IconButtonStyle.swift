// CoreMems/Views/Styles/IconButtonStyle.swift
import SwiftUI

enum IconButtonSize {
  case small
  case medium
  case large

  var diameter: CGFloat {
    switch self {
    case .small: return 36
    case .medium: return 48
    case .large: return 64
    }
  }

  fileprivate var glyphSize: CGFloat {
    switch self {
    case .small: return 16
    case .medium: return 20
    case .large: return 24
    }
  }
}

enum IconButtonSurface {
  /// Tinted glyph on a faint fill of the same color.
  case tinted(Color)
  /// Glyph on a thin material, for navigation chrome.
  case material(Color)
  /// White glyph on a dark scrim, for controls drawn over photos.
  case scrim
  /// Glyph only, for containers that supply their own background.
  case bare(Color)

  fileprivate var glyphColor: Color {
    switch self {
    case .tinted(let color), .material(let color), .bare(let color): return color
    case .scrim: return .white
    }
  }

  @ViewBuilder
  fileprivate var background: some View {
    switch self {
    case .tinted(let color): Circle().fill(color.opacity(0.16))
    case .material: Circle().fill(.thinMaterial)
    case .scrim: Circle().fill(.black.opacity(0.55))
    case .bare: Color.clear
    }
  }
}

/// Circular icon-only button. The label is a single `Image`.
struct IconButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  let size: IconButtonSize
  let surface: IconButtonSurface

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: size.glyphSize, weight: .semibold))
      .foregroundStyle(surface.glyphColor)
      .frame(width: size.diameter, height: size.diameter)
      .background { surface.background }
      .contentShape(Circle())
      .opacity(ButtonMetrics.opacity(isPressed: configuration.isPressed, isEnabled: isEnabled))
  }
}
