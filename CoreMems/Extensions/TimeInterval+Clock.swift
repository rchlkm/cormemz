// CoreMems/Extensions/TimeInterval+Clock.swift
import Foundation

extension TimeInterval {
  /// A playback position or length as minutes and seconds, like "1:05".
  var clockText: String {
    Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
  }
}
