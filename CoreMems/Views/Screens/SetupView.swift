// CoreMems/Views/Screens/SetupView.swift
import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  @Binding var checkInInterval: Int
  @Binding var includesReviewedPhotos: Bool
  let reviewedPhotoCount: Int
  let onResetReviewedPhotos: () -> Void
  let pinnedAlbums: [AlbumOption]
  let pinnedAlbumIdentifiers: Set<String>
  let isLoadingPinnedAlbums: Bool
  var isCreatingPinnedAlbum: Bool = false
  var pinnedAlbumCreationError: String? = nil
  let onLoadPinnedAlbums: () -> Void
  let onTogglePinnedAlbum: (String) -> Void
  let onCreateAndPinAlbum: (String) -> Void
  let onStart: (SelectionMode, Date?) -> Void
  let onBack: () -> Void

  @State private var mode: SelectionMode = .shuffle
  @State private var selectedDate: Date?
  @State private var showCheckInSettings = false
  @State private var showReviewedPhotosSettings = false
  @State private var showPinnedAlbumsSettings = false

  private var canStart: Bool { mode != .date || selectedDate != nil }

  private var startButtonTitle: String {
    mode == .date && selectedDate == nil ? "Pick a date to start" : "Start"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TopBar(
        title: "New session",
        onBack: onBack,
        trailing: AnyView(
          HStack(spacing: 14) {
            pinnedAlbumsSettingsButton
            checkInSettingsButton
          }
        )
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

      reviewedPhotosButton

      Spacer()

      Button(startButtonTitle) {
        onStart(mode, mode == .date ? selectedDate : nil)
      }
      .buttonStyle(PrimaryActionButtonStyle())
      .disabled(!canStart)
      .opacity(canStart ? 1 : 0.5)
    }
    .sheet(isPresented: $showCheckInSettings) {
      CheckInSettingsView(value: $checkInInterval)
    }
    .sheet(isPresented: $showReviewedPhotosSettings) {
      ReviewedPhotosSettingsView(
        includesReviewed: $includesReviewedPhotos,
        reviewedCount: reviewedPhotoCount,
        onReset: onResetReviewedPhotos
      )
    }
    .sheet(isPresented: $showPinnedAlbumsSettings) {
      PinnedAlbumsSettingsView(
        albums: pinnedAlbums,
        pinnedIdentifiers: pinnedAlbumIdentifiers,
        isLoading: isLoadingPinnedAlbums,
        isCreating: isCreatingPinnedAlbum,
        creationError: pinnedAlbumCreationError,
        onTogglePin: onTogglePinnedAlbum,
        onCreateAndPin: onCreateAndPinAlbum
      )
    }
  }

  // MARK: - Reviewed photos settings entry point
  private var reviewedPhotosButton: some View {
    Button {
      showReviewedPhotosSettings = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle")
        Text(reviewedPhotosSummary)
      }
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.top, 10)
  }

  private var reviewedPhotosSummary: String {
    if includesReviewedPhotos { return "Including reviewed photos" }
    guard reviewedPhotoCount > 0 else { return "No reviewed photos yet" }
    return "Skipping \(reviewedPhotoCount) reviewed photo\(reviewedPhotoCount == 1 ? "" : "s")"
  }

  // MARK: - Pinned albums settings entry point
  private var pinnedAlbumsSettingsButton: some View {
    Button {
      onLoadPinnedAlbums()
      showPinnedAlbumsSettings = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "pin")
        Text("Albums")
      }
      .font(.system(size: 12.5, weight: .semibold))
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Check-in settings entry point
  private var checkInSettingsButton: some View {
    Button {
      showCheckInSettings = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "slider.horizontal.3")
        Text("Every \(checkInInterval)")
      }
      .font(.system(size: 12.5, weight: .semibold))
      .foregroundStyle(.secondary)
    }
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
  SetupView(
    maxAvailable: 200, checkInInterval: .constant(12),
    includesReviewedPhotos: .constant(false), reviewedPhotoCount: 128,
    onResetReviewedPhotos: {}, pinnedAlbums: [],
    pinnedAlbumIdentifiers: [], isLoadingPinnedAlbums: false, onLoadPinnedAlbums: {},
    onTogglePinnedAlbum: { _ in }, onCreateAndPinAlbum: { _ in }, onStart: { _, _ in }, onBack: {}
  )
  .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  SetupView(
    maxAvailable: 200, checkInInterval: .constant(12),
    includesReviewedPhotos: .constant(false), reviewedPhotoCount: 128,
    onResetReviewedPhotos: {}, pinnedAlbums: [],
    pinnedAlbumIdentifiers: [], isLoadingPinnedAlbums: false, onLoadPinnedAlbums: {},
    onTogglePinnedAlbum: { _ in }, onCreateAndPinAlbum: { _ in }, onStart: { _, _ in }, onBack: {}
  )
  .preferredColorScheme(.dark)
}
