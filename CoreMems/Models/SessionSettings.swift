// CoreMems/Models/SessionSettings.swift
import Foundation

/// User preferences for reviewing, written to `UserDefaults` on every change.
struct SessionSettings {
  static let checkInIntervalRange = 5...50
  static let defaultCheckInInterval = 12
  private static let checkInIntervalKey = "cm_checkInInterval"
  private static let includesReviewedKey = "cm_includesReviewedPhotos"

  private let defaults: UserDefaults

  /// How many photos pass between check-in overlays during review.
  var checkInInterval: Int {
    didSet { defaults.set(checkInInterval, forKey: Self.checkInIntervalKey) }
  }

  /// When true, sessions also include photos kept in earlier sessions.
  var includesReviewedPhotos: Bool {
    didSet { defaults.set(includesReviewedPhotos, forKey: Self.includesReviewedKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let range = Self.checkInIntervalRange
    checkInInterval =
      (defaults.object(forKey: Self.checkInIntervalKey) as? Int).map {
        min(max($0, range.lowerBound), range.upperBound)
      } ?? Self.defaultCheckInInterval
    includesReviewedPhotos = defaults.bool(forKey: Self.includesReviewedKey)
  }
}
