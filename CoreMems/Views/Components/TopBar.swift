// CoreMems/Views/Components/TopBar.swift
import SwiftUI

struct TopBar: View {
  let title: String
  var onBack: (() -> Void)? = nil
  var leading: AnyView? = nil
  var trailing: AnyView? = nil

  private let controlSize = IconButtonSize.small

  var body: some View {
    HStack {
      if let leading {
        leading
      } else {
        Button(action: { onBack?() }) {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(IconButtonStyle(size: controlSize, surface: .material(.primary)))
        .opacity(onBack == nil ? 0 : 1)
      }

      Spacer()
      Text(title).font(.headline)
      Spacer()

      if let trailing {
        trailing
      } else {
        Color.clear.frame(width: controlSize.diameter, height: controlSize.diameter)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }
}
