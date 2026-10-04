// CoreMems/Views/Components/CaptureDateBadge.swift
import SwiftUI

/// When a photo was taken, on a frosted badge for drawing over the photo.
struct CaptureDateBadge: View {
  let date: String
  var time: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(date)
        .font(.subheadline.weight(.bold))
      if !time.isEmpty {
        Text(time)
          .font(.caption2.weight(.medium))
          .opacity(0.8)
          .padding(.top, 1)
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frostedGlass(in: RoundedRectangle(cornerRadius: 14), interactive: false)
  }
}

#Preview {
  CaptureDateBadge(date: "Oct 3, 2026", time: "8:35 PM PDT")
    .padding()
    .background(.teal)
}
