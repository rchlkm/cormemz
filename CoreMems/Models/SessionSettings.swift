// CoreMems/Models/SessionSettings.swift
import Foundation

/// User preferences for reviewing, written to `UserDefaults` on every change.
struct SessionSettings {
  static let checkInIntervalRange = 5...50
  static let defaultCheckInInterval = 12
  /// Photos a session loads before it goes to Pending Review, so nothing stays staged for long.
  static let maxPhotosPerSession = 200
  private static let checkInIntervalKey = "cm_checkInInterval"
  private static let includesReviewedKey = "cm_includesReviewedPhotos"
  private static let networkPolicyKey = "cm_networkPolicy"
  private static let defaultSessionModeKey = "cm_defaultSessionMode"

  private let defaults: UserDefaults

  /// How many photos pass between check-in overlays during review.
  var checkInInterval: Int {
    didSet { defaults.set(checkInInterval, forKey: Self.checkInIntervalKey) }
  }

  /// When true, sessions also include photos kept in earlier sessions.
  var includesReviewedPhotos: Bool {
    didSet { defaults.set(includesReviewedPhotos, forKey: Self.includesReviewedKey) }
  }

  /// Where photos missing from the device may be downloaded from.
  var networkPolicy: NetworkPolicy {
    didSet { defaults.set(networkPolicy.rawValue, forKey: Self.networkPolicyKey) }
  }

  /// Which mode Setup opens with.
  var defaultSessionMode: SelectionMode {
    didSet { defaults.set(defaultSessionMode.rawValue, forKey: Self.defaultSessionModeKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let range = Self.checkInIntervalRange
    checkInInterval =
      (defaults.object(forKey: Self.checkInIntervalKey) as? Int).map {
        min(max($0, range.lowerBound), range.upperBound)
      } ?? Self.defaultCheckInInterval
    includesReviewedPhotos = defaults.bool(forKey: Self.includesReviewedKey)
    networkPolicy =
      defaults.string(forKey: Self.networkPolicyKey).flatMap(NetworkPolicy.init(rawValue:))
      ?? .wifiAndCellular
    defaultSessionMode =
      defaults.string(forKey: Self.defaultSessionModeKey).flatMap(SelectionMode.init)
      ?? .shuffle
  }
}
