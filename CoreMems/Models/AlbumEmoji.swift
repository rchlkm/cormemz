// CoreMems/Models/AlbumEmoji.swift
import Foundation

/// A single emoji that stands in for an album's icon.
struct AlbumEmoji: Hashable {
  let value: String

  /// Nil unless `text` is exactly one emoji.
  init?(_ text: String) {
    guard text.count == 1, let first = text.unicodeScalars.first,
      first.properties.isEmoji,
      first.properties.isEmojiPresentation || text.unicodeScalars.count > 1
    else { return nil }
    value = text
  }
}
