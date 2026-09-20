// CoreMems/Views/Screens/DeniedAccessView.swift
import SwiftUI

struct DeniedAccessView: View {
  let onOpenSettings: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.slash")
        .font(.system(size: 26, weight: .light))
        .foregroundStyle(.secondary)
        .frame(width: 60, height: 60)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

      Text("Photos access is off")
        .font(.title2.bold())

      Text(
        "Core Mems can't review your photos without access. Turn it on in Settings — you can allow all photos, or just a select few."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 34)

      Button("Open Settings", action: onOpenSettings)
        .buttonStyle(ActionButtonStyle(role: .primary))
        .padding(.horizontal, 60)
      .padding(.top, 6)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  DeniedAccessView(onOpenSettings: {})
}
