// CoreMems/Services/LifetimeStatsService.swift
import Foundation

struct LifetimeSessionStats: Codable {
  var totalReviewed = 0
  var totalKept = 0
  var totalDeleted = 0
  var sessionsCompleted = 0
  var trackingSince: Date?
}

protocol LifetimeStatsServicing {
  func currentStats() -> LifetimeSessionStats
  @discardableResult
  func recordSession(kept: Int, deleted: Int) -> LifetimeSessionStats
  func clear()
}

/// File-backed lifetime stats, stored in the app's Application Support
/// directory alongside the active-session snapshot. Survives relaunch
/// and background/kill; removed automatically only if the app itself
/// is deleted.
final class LifetimeStatsService: LifetimeStatsServicing {
  private let fileURL: URL

  init() {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    // The Application Support directory is not created automatically on iOS.
    // Without this, writes fail silently and stats never persist.
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("core-mems-lifetime-stats.json")
  }

  func currentStats() -> LifetimeSessionStats {
    guard let data = try? Data(contentsOf: fileURL),
      let stats = try? JSONDecoder().decode(LifetimeSessionStats.self, from: data)
    else {
      return LifetimeSessionStats()
    }
    return stats
  }

  @discardableResult
  func recordSession(kept: Int, deleted: Int) -> LifetimeSessionStats {
    var stats = currentStats()
    if stats.trackingSince == nil { stats.trackingSince = Date() }
    stats.totalReviewed += kept + deleted
    stats.totalKept += kept
    stats.totalDeleted += deleted
    stats.sessionsCompleted += 1
    save(stats)
    print("[CoreMems] session stats:", stats)
    return stats
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func save(_ stats: LifetimeSessionStats) {
    guard let data = try? JSONEncoder().encode(stats) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}

#if DEBUG
  final class MockLifetimeStatsService: LifetimeStatsServicing {
    var stats = LifetimeSessionStats()

    func currentStats() -> LifetimeSessionStats { stats }

    @discardableResult
    func recordSession(kept: Int, deleted: Int) -> LifetimeSessionStats {
      if stats.trackingSince == nil { stats.trackingSince = Date() }
      stats.totalReviewed += kept + deleted
      stats.totalKept += kept
      stats.totalDeleted += deleted
      stats.sessionsCompleted += 1
      return stats
    }

    func clear() { stats = LifetimeSessionStats() }
  }
#endif
