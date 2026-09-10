import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  let onStart: (Int) -> Void
  let onBack: () -> Void

  @State private var size: Int = 10

  private let options = [10, 25, 50]

  private var capped: Int { min(size, maxAvailable) }
  private var shrunk: Bool { capped < size }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "New session", onBack: onBack)

      VStack(alignment: .leading, spacing: 6) {
        Text("How many photos?")
          .font(.title2.bold())
        Text(
          "We'll pick a random handful from your library. You can stop anytime — nothing is deleted until the very end."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 26)
      .padding(.top, 8)

      HStack(spacing: 6) {
        ForEach(options, id: \.self) { n in
          Button {
            size = n
          } label: {
            Text("\(n)")
              .font(.title3.weight(.bold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(
                size == n ? Color.blue.opacity(0.18) : .clear,
                in: RoundedRectangle(cornerRadius: 15)
              )
              .foregroundStyle(size == n ? .blue : .primary)
          }
        }
      }
      .padding(6)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
      .padding(.horizontal, 26)
      .padding(.top, 20)

      if shrunk {
        Text(
          "Only \(maxAvailable) eligible photo\(maxAvailable == 1 ? "" : "s") available right now — the session will use \(capped) instead."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 26)
        .padding(.top, 14)
      }

      Spacer()

      Button {
        onStart(capped)
      } label: {
        Text("Start cleanup session")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .buttonStyle(.borderedProminent)
      .padding(26)
    }
  }
}

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

#Preview {
  SetupView(maxAvailable: 200, onStart: { _ in }, onBack: {})
}
