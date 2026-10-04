// CoreMems/Models/SessionSettings.swift
import Foundation

/// User preferences for browsing, written to `UserDefaults` on every change.
struct SessionSettings {
  static let checkInIntervalRange = 5...50
  static let defaultCheckInInterval = 12
  /// Photos a session loads before it shows Apply Changes, so nothing stays staged for long.
  static let maxPhotosPerSession = 200
  private static let checkInIntervalKey = "cm_checkInInterval"
  private static let includesKeptKey = "cm_includesKeptPhotos"
  private static let tracksKeptHistoryKey = "cm_tracksKeptHistory"
  private static let networkPolicyKey = "cm_networkPolicy"
  private static let defaultSessionModeKey = "cm_defaultSessionMode"

  private let defaults: UserDefaults

  /// How many photos pass between check-in overlays during browsing.
  var checkInInterval: Int {
    didSet { defaults.set(checkInInterval, forKey: Self.checkInIntervalKey) }
  }

  /// When true, sessions also include photos kept in earlier sessions.
  var includesKeptPhotos: Bool {
    didSet { defaults.set(includesKeptPhotos, forKey: Self.includesKeptKey) }
  }

  /// When false, sessions stop recording newly kept photos, so they may be shown
  /// again later. Doesn't clear photos already recorded.
  var tracksKeptHistory: Bool {
    didSet { defaults.set(tracksKeptHistory, forKey: Self.tracksKeptHistoryKey) }
  }

  /// Where photos missing from the device may be downloaded from.
  var networkPolicy: NetworkPolicy {
    didSet { defaults.set(networkPolicy.rawValue, forKey: Self.networkPolicyKey) }
  }

  /// Which mode Home opens with.
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
    includesKeptPhotos = defaults.bool(forKey: Self.includesKeptKey)
    tracksKeptHistory =
      (defaults.object(forKey: Self.tracksKeptHistoryKey) as? Bool) ?? true
    networkPolicy =
      defaults.string(forKey: Self.networkPolicyKey).flatMap(NetworkPolicy.init(rawValue:))
      ?? .wifiAndCellular
    defaultSessionMode =
      defaults.string(forKey: Self.defaultSessionModeKey).flatMap(SelectionMode.init)
      ?? .shuffle
  }
}
