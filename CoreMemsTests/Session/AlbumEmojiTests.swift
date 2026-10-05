// CoreMemsTests/Session/AlbumEmojiTests.swift
import Testing

@testable import CoreMems

@Suite("Pin emoji")
struct AlbumEmojiTests {
  @Test(arguments: ["📌", "⭐️", "❤️", "1️⃣", "👍🏽"])
  func acceptsASingleEmoji(text: String) {
    #expect(AlbumEmoji(text)?.value == text)
  }

  @Test(arguments: ["", "a", "1", "#", "📌📍", "pin", " "])
  func rejectsAnythingElse(text: String) {
    #expect(AlbumEmoji(text) == nil)
  }
}
