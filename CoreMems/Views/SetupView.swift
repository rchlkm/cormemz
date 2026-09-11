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

  @State private var selectedCount: Int? = 10
  @State private var customInputText: String = ""
  @FocusState private var isCustomFieldFocused: Bool

  private let presetOptions: [OptionItem] = [
    OptionItem(count: 12, title: "12 photos", subtitle: "About a minute", badge: "Easy start"),
    OptionItem(count: 25, title: "25 photos", subtitle: "A few minutes", badge: nil),
  ]

  private var effectiveCount: Int {
    if let selectedCount {
      return selectedCount
    }
    let parsed = Int(customInputText) ?? 0
    return parsed > 0 ? parsed : 10
  }

  private var capped: Int { min(effectiveCount, maxAvailable) }
  private var shrunk: Bool { capped < effectiveCount }

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        TopBar(title: "New session", onBack: onBack)

        // Header
        VStack(alignment: .leading, spacing: 8) {
          Text("How many to review?")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.primary)

          Text("You can always stop whenever")
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)

        // Options List
        VStack(spacing: 12) {
          // Pass key path directly to ForEach
          ForEach(presetOptions, id: \.count) { option in
            let isSelected = selectedCount == option.count

            optionRow(
              title: option.title,
              subtitle: option.subtitle,
              badge: option.badge,
              isSelected: isSelected,
              action: {
                selectedCount = option.count
                isCustomFieldFocused = false
              },
              iconContent: { Text("\(option.count)") }
            )
          }

          // Custom Amount Card
          let isCustomSelected = selectedCount == nil
          optionRow(
            title: "Custom amount",
            subtitle: isCustomSelected
              ? (customInputText.isEmpty ? "Type a number" : "\(capped) photos selected")
              : "Choose your own limit",
            badge: nil,
            isSelected: isCustomSelected,
            action: {
              selectedCount = nil
              isCustomFieldFocused = true
            },
            iconContent: {
              if isCustomSelected {
                TextField("", text: $customInputText)
                  .keyboardType(.numberPad)
                  .multilineTextAlignment(.center)
                  .focused($isCustomFieldFocused)
              } else {
                Image(systemName: "number")
              }
            }
          )
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

        Button("Start") {
          onStart(capped)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
      }
    }
  }

  // MARK: - Private Option Row Builder
  @ViewBuilder
  private func optionRow<Content: View>(
    title: String,
    subtitle: String,
    badge: String?,
    isSelected: Bool,
    action: @escaping () -> Void,
    @ViewBuilder iconContent: () -> Content
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 16) {
        iconContent()
          .font(.system(size: 16, weight: .bold))
          .frame(width: 44, height: 44)
          .background(innerBoxColor(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 17, weight: .semibold))

          Text(subtitle)
            .font(.system(size: 14))
            .foregroundColor(secondaryTextColor(isSelected: isSelected))
        }

        Spacer()

        if let badge {
          Text(badge)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(innerBoxColor(isSelected: isSelected), in: Capsule())
        }
      }
    }
    .buttonStyle(CardButtonStyle(isSelected: isSelected))
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
