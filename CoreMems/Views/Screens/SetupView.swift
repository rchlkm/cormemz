// CoreMems/Views/Screens/SetupView.swift
import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  var isStarting: Bool = false
  var onPickRandomDate: () async -> Date? = { nil }
  let onOpenSettings: () -> Void
  let onStart: (SelectionMode, Date?) -> Void
  let onRefresh: () -> Void

  @State private var mode: SelectionMode = .shuffle
  @State private var selectedDate: Date?

  private var canStart: Bool { mode != .date || selectedDate != nil }

  private var startButtonTitle: String {
    mode == .date && selectedDate == nil ? "Pick a date to start" : "Start"
  }

  /// Fills in a fresh random date each time "From a Date" is chosen; the user can change it.
  private func prefillRandomDate() async {
    if let date = await onPickRandomDate() { selectedDate = date }
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
        .task(id: mode) { if mode == .date { await prefillRandomDate() } }
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
            .lineLimit(2, reservesSpace: true)
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
  /// Appears once the random date has loaded.
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
      return "Everything from that day forward, oldest first. Starts on a random day unless you pick one."
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
