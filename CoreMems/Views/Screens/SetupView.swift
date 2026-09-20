// CoreMems/Views/Screens/SetupView.swift
import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  var isStarting: Bool = false
  let onOpenSettings: () -> Void
  let onStart: (SelectionMode, Date?) -> Void
  let onBack: () -> Void

  @State private var mode: SelectionMode = .shuffle
  @State private var selectedDate: Date?

  private var canStart: Bool { mode != .date || selectedDate != nil }

  private var startButtonTitle: String {
    mode == .date && selectedDate == nil ? "Pick a date to start" : "Start"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(
        title: "New session",
        onBack: onBack,
        trailing: AnyView(settingsButton)
      )

      VStack(alignment: .leading, spacing: 20) {
        modePicker

        VStack(alignment: .leading, spacing: 8) {
          Text(mode.heading)
            .font(.system(size: 28, weight: .bold))
          Text("You can always stop whenever — nothing's deleted until the end.")
            .font(.system(size: 15))
            .foregroundColor(.secondary)
        }

        if mode == .date {
          datePicker
        } else {
          Text(mode.blurb)
            .font(.system(size: 13.5))
            .foregroundColor(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              Color(uiColor: .secondarySystemGroupedBackground),
              in: RoundedRectangle(cornerRadius: 16))
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 24)

      Text("The session adjusts quietly if fewer photos are available.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 26)
        .padding(.top, 14)

      Spacer()

      Button {
        onStart(mode, mode == .date ? selectedDate : nil)
      } label: {
        if isStarting {
          ProgressView()
        } else {
          Text(startButtonTitle)
        }
      }
      .buttonStyle(ActionButtonStyle(role: .primary))
      .disabled(!canStart || isStarting)
      .padding(.horizontal, 32)
      .padding(.bottom, 26)
    }
  }

  // MARK: - Settings entry point
  private var settingsButton: some View {
    Button(action: onOpenSettings) {
      Image(systemName: "gearshape")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .material(.primary)))
    .accessibilityLabel("Settings")
  }

  // MARK: - Mode picker (3-card row)
  private var modePicker: some View {
    HStack(spacing: 8) {
      ForEach(SelectionMode.allCases, id: \.self) { candidate in
        modeCard(candidate)
      }
    }
  }

  private func modeCard(_ candidate: SelectionMode) -> some View {
    Button {
      mode = candidate
    } label: {
      VStack(spacing: 4) {
        Text(candidate.icon)
          .font(.system(size: 18))
        Text(candidate.label)
          .font(.system(size: 12, weight: .bold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 11)
    }
    .buttonStyle(CardButtonStyle(isSelected: mode == candidate))
  }

  // MARK: - Date picker ("From a Date" mode)
  private var datePicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("STARTING ON")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(.secondary)

      DatePicker(
        "Starting on",
        selection: Binding(get: { selectedDate ?? Date() }, set: { selectedDate = $0 }),
        in: ...Date(),
        displayedComponents: .date
      )
      .labelsHidden()
      .datePickerStyle(.compact)

      Text(SelectionMode.date.blurb)
        .font(.system(size: 12.5))
        .foregroundColor(.secondary)
    }
  }
}

/// Setup-screen display text for each selection mode.
extension SelectionMode {
  fileprivate var icon: String {
    switch self {
    case .shuffle: return "🔀"
    case .recent: return "🕒"
    case .date: return "📅"
    }
  }

  fileprivate var label: String {
    switch self {
    case .shuffle: return "Shuffle"
    case .recent: return "Most Recent"
    case .date: return "From a Date"
    }
  }

  fileprivate var heading: String {
    switch self {
    case .shuffle: return "Shuffle and review"
    case .recent: return "Review your most recent photos"
    case .date: return "Review from a specific date"
    }
  }

  fileprivate var blurb: String {
    switch self {
    case .shuffle:
      return "Pulls random photos from your whole library, one at a time."
    case .recent:
      return "Starts with today and works backward through your library."
    case .date:
      return
        "Reviews everything from that day forward, oldest first — handy for picking up right where a trip started."
    }
  }
}

#Preview("Light Mode") {
  SetupView(maxAvailable: 200, onOpenSettings: {}, onStart: { _, _ in }, onBack: {})
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  SetupView(maxAvailable: 200, onOpenSettings: {}, onStart: { _, _ in }, onBack: {})
    .preferredColorScheme(.dark)
}
