// CoreMems/Views/Screens/SetupView.swift
import SwiftUI

struct SetupView: View {
  let maxAvailable: Int
  var isStarting: Bool = false
  var onPickRandomDate: () async -> Date? = { nil }
  /// Loads the album catalog; deferred until "Album" is actually chosen, since most
  /// sessions never touch it.
  var onPrepareAlbumPicker: () async -> Void = {}
  let onOpenSettings: () -> Void
  let onStart: (SelectionMode, Date?, AlbumOption?, MediaTypeFilter) -> Void
  let onRefresh: () -> Void
  /// The mode Setup opens with (Settings > Default session mode), labeled in the mode list.
  let defaultMode: SelectionMode
  /// Pinned albums, then unpinned recents, for the album picker's quick-access sections.
  var quickAccessAlbums: [AlbumOption] = []
  /// The whole library, nil until loaded.
  var libraryAlbums: [AlbumOption]? = []
  var libraryAlbumGroups: [AlbumGroup] = []
  var recentAlbumIDs: [String] = []
  var pinnedAlbums: PinnedAlbumsViewModel

  @State private var mode: SelectionMode
  @State private var selectedDate: Date?
  @State private var selectedAlbum: AlbumOption?
  @State private var showAlbumPicker = false
  @State private var mediaTypeFilter: MediaTypeFilter = .all

  init(
    maxAvailable: Int, isStarting: Bool = false, defaultMode: SelectionMode = .shuffle,
    onPickRandomDate: @escaping () async -> Date? = { nil },
    onPrepareAlbumPicker: @escaping () async -> Void = {},
    onOpenSettings: @escaping () -> Void,
    onStart: @escaping (SelectionMode, Date?, AlbumOption?, MediaTypeFilter) -> Void,
    onRefresh: @escaping () -> Void,
    quickAccessAlbums: [AlbumOption] = [],
    libraryAlbums: [AlbumOption]? = [],
    libraryAlbumGroups: [AlbumGroup] = [],
    recentAlbumIDs: [String] = [],
    pinnedAlbums: PinnedAlbumsViewModel
  ) {
    self.maxAvailable = maxAvailable
    self.isStarting = isStarting
    self.onPickRandomDate = onPickRandomDate
    self.onPrepareAlbumPicker = onPrepareAlbumPicker
    self.onOpenSettings = onOpenSettings
    self.onStart = onStart
    self.onRefresh = onRefresh
    self.quickAccessAlbums = quickAccessAlbums
    self.libraryAlbums = libraryAlbums
    self.libraryAlbumGroups = libraryAlbumGroups
    self.recentAlbumIDs = recentAlbumIDs
    self.pinnedAlbums = pinnedAlbums
    self.defaultMode = defaultMode
    _mode = State(initialValue: defaultMode)
  }

  private var canStart: Bool {
    (mode != .date || selectedDate != nil) && (mode != .album || selectedAlbum != nil)
  }

  private var startButtonTitle: String {
    if mode == .date && selectedDate == nil { return "Pick a date to start" }
    if mode == .album && selectedAlbum == nil { return "Choose an album to start" }
    return "Start"
  }

  /// Fills in a fresh random date each time "From a Date" is chosen; the user can change it.
  private func prefillRandomDate() async {
    if let date = await onPickRandomDate() { selectedDate = date }
  }

  /// Resolves a picked album's full details from the catalog the picker drew it from.
  private func resolveAlbum(_ ref: AlbumRef) -> AlbumOption? {
    pinnedAlbums.albums(withIdentifiers: [ref.identifier]).first
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
          } else if mode == .album {
            albumChooser
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .task(id: mode) {
          if mode == .date { await prefillRandomDate() }
          else if mode == .album { await onPrepareAlbumPicker() }
        }
      }

      Button {
        onStart(
          mode, mode == .date ? selectedDate : nil, mode == .album ? selectedAlbum : nil,
          mediaTypeFilter)
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
    .sheet(isPresented: $showAlbumPicker) {
      AlbumPickerView(
        albums: quickAccessAlbums,
        libraryAlbums: libraryAlbums,
        groups: libraryAlbumGroups,
        recentAlbumIDs: recentAlbumIDs,
        pinnedAlbums: pinnedAlbums,
        isSingleSelect: true,
        onToggle: { ref in selectedAlbum = resolveAlbum(ref) },
        title: "Choose an Album"
      )
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
          HStack(spacing: 6) {
            Text(candidate.label)
              .font(.system(size: 16, weight: .semibold))
            if candidate == defaultMode {
              Text("DEFAULT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
          }
          Text(candidate.blurb)
            .font(.system(size: 13))
            .foregroundColor(secondaryTextColor(isSelected: isSelected))
            .lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(CardButtonStyle(isSelected: isSelected))
  }

  // MARK: - Media type filter
  private var typeFilterRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(MediaTypeFilter.allCases, id: \.self) { filter in
          Button(filter.label) { mediaTypeFilter = filter }
            .buttonStyle(ChipButtonStyle(isSelected: filter == mediaTypeFilter))
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

  // MARK: - Album chooser ("Album" mode)
  private var albumChooser: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("ALBUM")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(.secondary)

      Button {
        showAlbumPicker = true
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(selectedAlbum?.name ?? "Choose an Album")
              .foregroundStyle(selectedAlbum == nil ? Color.accentColor : Color.primary)
            if let count = selectedAlbum?.countLabel {
              Text(count)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
    }
  }
}

/// Display text for each media type filter; shared by Setup's filter chip row.
extension MediaTypeFilter {
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

/// Display text for each selection mode; shared by Setup's mode picker and the
/// default-session-mode setting.
extension SelectionMode {
  var icon: String {
    switch self {
    case .shuffle: return "shuffle"
    case .recent: return "clock"
    case .date: return "calendar"
    case .album: return "photo.stack"
    }
  }

  var label: String {
    switch self {
    case .shuffle: return "Shuffle"
    case .recent: return "Most Recent"
    case .date: return "From a Date"
    case .album: return "Album"
    }
  }

  var blurb: String {
    switch self {
    case .shuffle:
      return "Random photos from your whole library, one at a time."
    case .recent:
      return "Starts with today and works backward."
    case .date:
      return "Starts on that day and works backward. Picks a random day unless you choose one."
    case .album:
      return "Review one album's photos, newest first."
    }
  }
}

#Preview("Light Mode") {
  SetupView(
    maxAvailable: 200, onOpenSettings: {}, onStart: { _, _, _, _ in }, onRefresh: {},
    pinnedAlbums: .mock()
  )
  .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  SetupView(
    maxAvailable: 200, onOpenSettings: {}, onStart: { _, _, _, _ in }, onRefresh: {},
    pinnedAlbums: .mock()
  )
  .preferredColorScheme(.dark)
}
