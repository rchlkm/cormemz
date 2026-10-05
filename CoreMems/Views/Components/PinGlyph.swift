// CoreMems/Views/Components/PinGlyph.swift
import SwiftUI

extension EnvironmentValues {
  /// The emoji that replaces an album's icon, by album identifier.
  @Entry var albumEmoji: [String: AlbumEmoji] = [:]
}

/// The icon of a pinned album's chip: its emoji if it has one, else the pin symbol.
/// Sized by the surrounding font.
struct PinGlyph: View {
  let albumID: String
  @Environment(\.albumEmoji) private var emojis

  var body: some View {
    if let emoji = emojis[albumID] {
      Text(emoji.value)
    } else {
      Image(systemName: "pin.fill")
    }
  }
}
