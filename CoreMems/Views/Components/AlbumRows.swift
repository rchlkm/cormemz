// CoreMems/Views/Components/AlbumRows.swift
import SwiftUI

extension AlbumOption {
  var countLabel: String? {
    assetCount.map { "\($0) photo\($0 == 1 ? "" : "s")" }
  }
}

/// A plain folder glyph, so folders read differently from album icons.
struct FolderIcon: View {
  var body: some View {
    Image(systemName: "folder.fill")
      .font(.system(size: 24))
      .foregroundStyle(Color(.secondaryLabel))
      .frame(width: 38, height: 38)
  }
}

/// A photo-stack icon; a pin badge marks a pinned album. Albums yet to be created show a sparkle.
struct AlbumIcon: View {
  let album: AlbumOption
  let isPinned: Bool

  private var isPendingNew: Bool { album.ref.kind == .pendingNew }

  var body: some View {
    RoundedRectangle(cornerRadius: 9)
      .fill(isPendingNew ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
      .frame(width: 38, height: 38)
      .overlay {
        Image(systemName: isPendingNew ? "sparkles" : "photo.stack.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(isPendingNew ? Color.white : Color(.secondaryLabel))
      }
      .overlay(alignment: .topTrailing) {
        if isPinned {
          Image(systemName: "pin.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.accentColor, in: Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .offset(x: 5, y: -5)
        }
      }
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
  }
}

/// An album row shared by the album sheet and Pinned Albums settings. The icon toggles the pin;
/// `onTap` covers the rest of the row.
struct AlbumRow<Trailing: View>: View {
  let album: AlbumOption
  let isPinned: Bool
  /// The containing folders, outermost first; shown when rows are listed outside their folder.
  let folderPath: [AlbumGroup]
  /// Nil for albums that can't be pinned.
  let onTogglePin: (() -> Void)?
  let onTap: (() -> Void)?
  let trailing: Trailing

  init(
    album: AlbumOption, isPinned: Bool, folderPath: [AlbumGroup] = [],
    onTogglePin: (() -> Void)? = nil, onTap: (() -> Void)? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.album = album
    self.isPinned = isPinned
    self.folderPath = folderPath
    self.onTogglePin = onTogglePin
    self.onTap = onTap
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: 12) {
      icon
      if let onTap {
        Button(action: onTap) { content.contentShape(Rectangle()) }
          .buttonStyle(.borderless)
      } else {
        content
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(album.name)
  }

  @ViewBuilder
  private var icon: some View {
    if let onTogglePin {
      Button(action: onTogglePin) { AlbumIcon(album: album, isPinned: isPinned) }
        .buttonStyle(.borderless)
        .accessibilityLabel(isPinned ? "Unpin \(album.name)" : "Pin \(album.name)")
    } else {
      AlbumIcon(album: album, isPinned: isPinned)
    }
  }

  private var content: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text(album.name)
          .foregroundStyle(Color.primary)
        if let count = album.countLabel {
          Text(count)
            .font(.caption)
            .foregroundStyle(Color(.secondaryLabel))
        }
        if !folderPath.isEmpty {
          FolderPathLabel(path: folderPath)
        }
      }
      Spacer(minLength: 0)
      trailing
    }
  }
}

extension AlbumRow where Trailing == EmptyView {
  init(
    album: AlbumOption, isPinned: Bool, folderPath: [AlbumGroup] = [],
    onTogglePin: (() -> Void)? = nil, onTap: (() -> Void)? = nil
  ) {
    self.init(
      album: album, isPinned: isPinned, folderPath: folderPath, onTogglePin: onTogglePin,
      onTap: onTap
    ) { EmptyView() }
  }
}

/// A folder row that opens the folder's contents.
struct FolderRow: View {
  let title: String
  let subtitle: String?
  let folderPath: [AlbumGroup]
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 12) {
        FolderIcon()
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .foregroundStyle(Color.primary)
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(Color(.secondaryLabel))
          }
          if !folderPath.isEmpty {
            FolderPathLabel(path: folderPath)
          }
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color(.tertiaryLabel))
      }
      .padding(.vertical, 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

/// A "Trips › 2024" breadcrumb.
struct FolderPathLabel: View {
  let path: [AlbumGroup]

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "folder")
      ForEach(Array(path.enumerated()), id: \.element.id) { index, folder in
        if index > 0 { Image(systemName: "chevron.right").font(.system(size: 8)) }
        Text(folder.name)
          .lineLimit(1)
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
