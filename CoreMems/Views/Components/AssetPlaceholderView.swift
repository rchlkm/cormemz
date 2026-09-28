// CoreMems/Views/Components/AssetPlaceholderView.swift
import SwiftUI

/// The tertiary-fill placeholder shown while an asset loads or fails to
/// load, shared by every asset renderer so the two states read the same
/// everywhere a photo or video can appear.
struct AssetPlaceholderView: View {
  enum State {
    case loading
    case failed(icon: String)
  }

  let state: State

  var body: some View {
    ZStack {
      Color(.tertiarySystemFill)
      switch state {
      case .loading:
        ProgressView()
      case .failed(let icon):
        Image(systemName: icon)
          .foregroundStyle(.tertiary)
      }
    }
  }
}
