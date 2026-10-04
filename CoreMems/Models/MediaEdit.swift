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

  /// Keeps `range` of a video `duration` seconds long; keeping all of it clears the trim and
  /// its options.
  mutating func trim(to range: ClosedRange<Double>, ofDuration duration: Double) {
    guard range.lowerBound > 0 || range.upperBound < duration else {
      trimRange = nil
      deletesOriginal = true
      return
    }
    trimRange = range
  }
}
