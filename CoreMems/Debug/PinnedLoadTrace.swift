// CoreMems/Debug/PinnedLoadTrace.swift
import Foundation
import os

/// Temporary timing log for opening Pinned Albums: time since the screen appeared at each
/// load step, plus main-thread stalls. Filter the console on "PinnedTrace".
@MainActor
enum PinnedLoadTrace {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "CoreMems", category: "PinnedTrace")
  private static let tick: TimeInterval = 0.05
  private static let stallThreshold = Duration.milliseconds(150)
  private static var start = ContinuousClock.now
  private static var lastTick = ContinuousClock.now
  private static var watcher: Timer?

  static func begin() {
    start = .now
    lastTick = .now
    log("screen appeared")
    watcher?.invalidate()
    watcher = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { _ in
      MainActor.assumeIsolated {
        let gap = ContinuousClock.now - lastTick
        lastTick = .now
        if gap > stallThreshold { log("main thread stalled for \(milliseconds(gap)) ms") }
      }
    }
  }

  static func end() {
    log("screen disappeared")
    watcher?.invalidate()
    watcher = nil
  }

  static func log(_ event: String) {
    logger.notice("[PinnedTrace] +\(milliseconds(ContinuousClock.now - start)) ms \(event)")
  }

  private static func milliseconds(_ duration: Duration) -> Int {
    let parts = duration.components
    return Int(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)
  }
}
