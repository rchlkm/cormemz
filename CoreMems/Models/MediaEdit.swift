// CoreMems/Models/MediaEdit.swift
import Foundation

/// Edits staged for one photo or video, written to the library on Apply.
nonisolated struct MediaEdit: Equatable, Codable {
  /// Counterclockwise quarter turns, 0...3.
  private(set) var quarterTurns = 0
  /// The part of a video to keep, in seconds; `nil` keeps all of it.
  var trimRange: ClosedRange<Double>?
  /// Whether a trimmed video's original is deleted once its trimmed copy is saved.
  var deletesOriginal = true

  var isEmpty: Bool { quarterTurns == 0 && trimRange == nil }

  mutating func rotate() {
    quarterTurns = (quarterTurns + 1) % 4
  }
}
