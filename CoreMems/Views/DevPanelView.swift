import SwiftUI

/// Preview-only affordance mirroring the JS prototype's Dev Panel.
// #if DEBUG
struct DevPanelView: View {
  @ObservedObject var vm: SessionViewModel
  @Binding var isOpen: Bool

  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      Button {
        isOpen.toggle()
      } label: {
        Label("Preview states", systemImage: "slider.horizontal.3")
          .font(.caption)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
      }

      if isOpen {
        VStack(alignment: .leading, spacing: 10) {
          Toggle("Limited Photos access", isOn: $vm.limitedAccess)
          Toggle("Empty library", isOn: $vm.emptyLibrary)
          Toggle(
            "Low inventory (cap 4)",
            isOn: Binding(
              get: { vm.maxAvailable == 4 },
              set: { vm.maxAvailable = $0 ? 4 : 200 }
            ))
        }
        .font(.caption)
        .toggleStyle(.switch)
        .padding(12)
        .frame(width: 220)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
      }
    }
  }
}
