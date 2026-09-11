import SwiftUI

struct TopBar: View {
  let title: String
  var onBack: (() -> Void)? = nil
  var trailing: AnyView? = nil

  var body: some View {
    HStack {
      Button(action: { onBack?() }) {
        Image(systemName: "chevron.left")
          .frame(width: 34, height: 34)
          .background(.thinMaterial, in: Circle())
      }
      .opacity(onBack == nil ? 0 : 1)

      Spacer()
      Text(title).font(.headline)
      Spacer()

      if let trailing {
        trailing
      } else {
        Color.clear.frame(width: 34, height: 34)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }
}
