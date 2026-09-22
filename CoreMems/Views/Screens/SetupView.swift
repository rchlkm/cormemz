// CoreMems/Views/Screens/SetupView.swift
import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  var isStarting: Bool = false
  let onOpenSettings: () -> Void
  let onStart: (SelectionMode, Date?) -> Void
  let onRefresh: () -> Void

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
        leading: AnyView(refreshButton),
        trailing: AnyView(settingsButton)
      )

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          typeFilterRow
          modeList
          if mode == .date {
            datePicker
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
      }

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
      .accessibilityIdentifier(AccessibilityID.setupStart)
      .disabled(!canStart || isStarting)
      .padding(.horizontal, 32)
      .padding(.bottom, 26)
    }
  }

  // MARK: - Refresh
  private var refreshButton: some View {
    Button(action: onRefresh) {
      Image(systemName: "arrow.clockwise")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .material(.primary)))
    .accessibilityLabel("Refresh")
  }

  // MARK: - Settings entry point
  private var settingsButton: some View {
    Button(action: onOpenSettings) {
      Image(systemName: "gearshape")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .material(.primary)))
    .accessibilityLabel("Settings")
  }

  // MARK: - Mode picker (scrollable option list)
  private var modeList: some View {
    VStack(spacing: 10) {
      ForEach(SelectionMode.allCases, id: \.self) { candidate in
        modeRow(candidate)
      }
    }
  }

  private func modeRow(_ candidate: SelectionMode) -> some View {
    let isSelected = mode == candidate
    return Button {
      mode = candidate
    } label: {
      HStack(spacing: 14) {
        Image(systemName: candidate.icon)
          .font(.system(size: 20, weight: .semibold))
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(candidate.label)
            .font(.system(size: 16, weight: .semibold))
          Text(candidate.blurb)
            .font(.system(size: 13))
            .foregroundColor(secondaryTextColor(isSelected: isSelected))
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(CardButtonStyle(isSelected: isSelected))
  }

  // MARK: - Media type filter (only "All" is wired up so far)
  private var typeFilterRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(MediaTypeFilter.allCases, id: \.self) { filter in
          Button(filter.label) {}
            .buttonStyle(ChipButtonStyle(isSelected: filter == .all))
            .disabled(filter != .all)
        }
      }
    }
  }

  // MARK: - Date picker ("From a Date" mode)
  /// Nothing is picked until the user taps to reveal the picker — it never shows
  /// today pre-filled while `selectedDate` is still nil underneath.
  private var datePicker: some View {
    Group {
      if let selectedDate {
        VStack(alignment: .leading, spacing: 10) {
          Text("STARTING ON")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.secondary)

          DatePicker(
            "Starting on",
            selection: Binding(get: { selectedDate }, set: { self.selectedDate = $0 }),
            in: ...Date(),
            displayedComponents: .date
          )
          .labelsHidden()
          .datePickerStyle(.compact)
        }
      } else {
        Button {
          self.selectedDate = Date()
        } label: {
          HStack(spacing: 14) {
            Image(systemName: "calendar")
              .font(.system(size: 20, weight: .semibold))
              .frame(width: 28)
            Text("Choose a date")
              .font(.system(size: 16, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(CardButtonStyle(isSelected: false))
      }
    }
  }
}

/// Media types a session can be limited to. Only `.all` filters anything today —
/// the rest are shown disabled until asset-type filtering is implemented.
private enum MediaTypeFilter: String, CaseIterable {
  case all, photos, screenshots, videos, timelapses

  var label: String {
    switch self {
    case .all: return "All"
    case .photos: return "Photos"
    case .screenshots: return "Screenshots"
    case .videos: return "Videos"
    case .timelapses: return "Timelapses"
    }
  }
}

/// Setup-screen display text for each selection mode.
extension SelectionMode {
  fileprivate var icon: String {
    switch self {
    case .shuffle: return "shuffle"
    case .recent: return "clock"
    case .date: return "calendar"
    }
  }

  fileprivate var label: String {
    switch self {
    case .shuffle: return "Shuffle"
    case .recent: return "Most Recent"
    case .date: return "From a Date"
    }
  }

  fileprivate var blurb: String {
    switch self {
    case .shuffle:
      return "Random photos from your whole library, one at a time."
    case .recent:
      return "Starts with today and works backward."
    case .date:
      return "Everything from that day forward, oldest first."
    }
  }
}

#Preview("Light Mode") {
  SetupView(maxAvailable: 200, onOpenSettings: {}, onStart: { _, _ in }, onRefresh: {})
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  SetupView(maxAvailable: 200, onOpenSettings: {}, onStart: { _, _ in }, onRefresh: {})
    .preferredColorScheme(.dark)
}
