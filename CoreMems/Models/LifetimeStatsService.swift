// CoreMems/Services/LifetimeStatsService.swift
import Foundation

struct LifetimeSessionStats: Codable {
  var totalReviewed = 0
  var totalKept = 0
  var totalDeleted = 0
  var bytesDeleted: Int64 = 0
  var livePhotosConverted = 0
  var bytesSavedByConversion: Int64 = 0
  var sessionsCompleted = 0
  var trackingSince: Date?

  var bytesCleaned: Int64 { bytesDeleted + bytesSavedByConversion }

  /// Kept photos left as they were; conversions are also counted in `totalKept`.
  var keptUnchanged: Int { max(totalKept - livePhotosConverted, 0) }

  mutating func recordSession(kept: Int, deleted: Int, bytesDeleted: Int64) {
    startTrackingIfNeeded()
    totalReviewed += kept + deleted
    totalKept += kept
    totalDeleted += deleted
    self.bytesDeleted += bytesDeleted
    sessionsCompleted += 1
  }

  mutating func recordLivePhotoConversion(bytesSaved: Int64) {
    startTrackingIfNeeded()
    livePhotosConverted += 1
    bytesSavedByConversion += bytesSaved
  }

  private mutating func startTrackingIfNeeded() {
    if trackingSince == nil { trackingSince = Date() }
  }
}

/// Decodes missing keys as zero so stats saved by earlier versions still load.
extension LifetimeSessionStats {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    totalReviewed = try container.decodeIfPresent(Int.self, forKey: .totalReviewed) ?? 0
    totalKept = try container.decodeIfPresent(Int.self, forKey: .totalKept) ?? 0
    totalDeleted = try container.decodeIfPresent(Int.self, forKey: .totalDeleted) ?? 0
    bytesDeleted = try container.decodeIfPresent(Int64.self, forKey: .bytesDeleted) ?? 0
    livePhotosConverted = try container.decodeIfPresent(Int.self, forKey: .livePhotosConverted) ?? 0
    bytesSavedByConversion =
      try container.decodeIfPresent(Int64.self, forKey: .bytesSavedByConversion) ?? 0
    sessionsCompleted = try container.decodeIfPresent(Int.self, forKey: .sessionsCompleted) ?? 0
    trackingSince = try container.decodeIfPresent(Date.self, forKey: .trackingSince)
  }
}

protocol LifetimeStatsServicing {
  func currentStats() -> LifetimeSessionStats
  @discardableResult
  func recordSession(kept: Int, deleted: Int, bytesDeleted: Int64) -> LifetimeSessionStats
  @discardableResult
  func recordLivePhotoConversion(bytesSaved: Int64) -> LifetimeSessionStats
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
  func recordSession(kept: Int, deleted: Int, bytesDeleted: Int64) -> LifetimeSessionStats {
    var stats = currentStats()
    stats.recordSession(kept: kept, deleted: deleted, bytesDeleted: bytesDeleted)
    save(stats)
    print("[CoreMems] session stats:", stats)
    return stats
  }

  @discardableResult
  func recordLivePhotoConversion(bytesSaved: Int64) -> LifetimeSessionStats {
    var stats = currentStats()
    stats.recordLivePhotoConversion(bytesSaved: bytesSaved)
    save(stats)
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
    func recordSession(kept: Int, deleted: Int, bytesDeleted: Int64) -> LifetimeSessionStats {
      stats.recordSession(kept: kept, deleted: deleted, bytesDeleted: bytesDeleted)
      return stats
    }

    @discardableResult
    func recordLivePhotoConversion(bytesSaved: Int64) -> LifetimeSessionStats {
      stats.recordLivePhotoConversion(bytesSaved: bytesSaved)
      return stats
    }

    func clear() { stats = LifetimeSessionStats() }
  }
#endif
