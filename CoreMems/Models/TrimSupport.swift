// CoreMems/Models/TrimSupport.swift
import Foundation

/// Whether a photo or video can be trimmed.
enum TrimSupport: Equatable {
  /// Not a video, so there is nothing to trim.
  case unavailable
  /// A video that can't be trimmed, such as slo-mo.
  case unsupported
  /// A video that can be trimmed across `duration` seconds.
  case supported(duration: Double)

  var duration: Double? {
    if case .supported(let duration) = self { return duration }
    return nil
  }
}
