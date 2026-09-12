import SwiftUI

struct OptionItem {
  let count: Int
  let title: String
  let subtitle: String
  let badge: String?
}

struct SetupView: View {
  let maxAvailable: Int
  let onStart: (Int) -> Void
  let onBack: () -> Void

  private let presetOptions: [OptionItem] = [
    OptionItem(count: 12, title: "12 photos", subtitle: "About a minute", badge: "Easy start"),
    OptionItem(count: 25, title: "25 photos", subtitle: "A few minutes", badge: nil),
  ]

  @State private var selectedCount: Int? = 12
  @State private var customInputText: String = ""
  @FocusState private var isCustomFieldFocused: Bool

  private var effectiveCount: Int {
    if let selectedCount { return selectedCount }
    let parsed = Int(customInputText) ?? 0
    return parsed > 0 ? parsed : 10
  }

  private var capped: Int { min(effectiveCount, maxAvailable) }
  private var shrunk: Bool { capped < effectiveCount }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(title: "New session", onBack: onBack)

      VStack(alignment: .leading, spacing: 8) {
        Text("How many to review?")
          .font(.system(size: 28, weight: .bold))
        Text("You can always stop whenever")
          .font(.system(size: 15))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 24)
      .padding(.top, 24)

      VStack(spacing: 12) {
        ForEach(presetOptions, id: \.count) { option in
          presetRow(option, isSelected: selectedCount == option.count)
        }
        customRow
      }
      .padding(.horizontal, 24)
      .padding(.top, 28)

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

      Button("Start") { onStart(capped) }
        .buttonStyle(PrimaryActionButtonStyle())
    }
  }

  // MARK: - Preset row (plain, no TextField → safe as a real Button)
  private func presetRow(_ option: OptionItem, isSelected: Bool) -> some View {
    Button {
      selectedCount = option.count
      isCustomFieldFocused = false
    } label: {
      HStack(spacing: 16) {
        Text("\(option.count)")
          .font(.system(size: 16, weight: .bold))
          .frame(width: 44, height: 44)
          .background(innerBoxColor(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 2) {
          Text(option.title).font(.system(size: 17, weight: .semibold))
          Text(option.subtitle)
            .font(.system(size: 14))
            .foregroundColor(secondaryTextColor(isSelected: isSelected))
        }

        Spacer()

        if let badge = option.badge {
          Text(badge)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(innerBoxColor(isSelected: isSelected), in: Capsule())
        }
      }
    }
    .buttonStyle(CardButtonStyle(isSelected: isSelected))
  }

  // MARK: - Custom row
  private var customRow: some View {
    let isCustomSelected = selectedCount == nil

    return HStack(spacing: 16) {
      ZStack {
        Image(systemName: "number")
          .opacity(isCustomSelected ? 0 : 1)
        TextField("", text: $customInputText)
          .keyboardType(.numberPad)
          .multilineTextAlignment(.center)
          .focused($isCustomFieldFocused)
          .opacity(isCustomSelected ? 1 : 0)
          .allowsHitTesting(isCustomSelected)
      }
      .font(.system(size: 16, weight: .bold))
      .frame(width: 44, height: 44)
      .background(
        innerBoxColor(isSelected: isCustomSelected), in: RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 2) {
        Text("Custom amount").font(.system(size: 17, weight: .semibold))
        Text(
          isCustomSelected
            ? (customInputText.isEmpty ? "Type a number" : "\(capped) photos selected")
            : "Choose your own limit"
        )
        .font(.system(size: 14))
        .foregroundColor(secondaryTextColor(isSelected: isCustomSelected))
      }

      Spacer()
    }
    .padding(16)
    .background(isCustomSelected ? (Color(.label).opacity(0.0)) : Color.clear)  // keep row static, CardButtonStyle handled below
    .modifier(RowCardBackground(isSelected: isCustomSelected))
    .contentShape(Rectangle())
    .onTapGesture {
      // Tapping the row (outside the TextField) selects "custom" mode.
      // The TextField sits on top and handles its own taps for focus.
      if !isCustomSelected {
        selectedCount = nil
        isCustomFieldFocused = true
      }
    }
  }
}

/// Same visual treatment as `CardButtonStyle`, but usable outside a
/// `Button` so it can wrap a row that also contains a `TextField`.
private struct RowCardBackground: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let isSelected: Bool

  func body(content: Content) -> some View {
    content
      .background(background, in: RoundedRectangle(cornerRadius: 20))
      .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .primary)
      .animation(.snappy(duration: 0.2), value: isSelected)
  }

  private var background: Color {
    if isSelected { return colorScheme == .dark ? .white : .black }
    return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : .white
  }
}

#Preview("Light Mode") {
  SetupView(maxAvailable: 200, onStart: { _ in }, onBack: {})
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  SetupView(maxAvailable: 200, onStart: { _ in }, onBack: {})
    .preferredColorScheme(.dark)
}
