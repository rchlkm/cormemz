// CoreMems/Services/LifetimeStatsService.swift
import Foundation

struct LifetimeSessionStats: Codable {
  /// Bump when the stored shape changes; lets a future migration branch on
  /// what it's actually reading instead of guessing from which keys are present.
  static let currentSchemaVersion = 1

  var schemaVersion = Self.currentSchemaVersion
  var totalKept = 0
  var totalDeleted = 0
  var bytesDeleted: Int64 = 0
  var livePhotosConverted = 0
  var bytesSavedByConversion: Int64 = 0
  var bytesSavedByTrimming: Int64 = 0
  var mediaEdited = 0
  var sessionsCompleted = 0
  var trackingSince: Date?

  /// Every decision made, kept or deleted. Derived, never stored, so it can't
  /// drift out of sync with `totalKept`/`totalDeleted`.
  var totalDecided: Int { totalKept + totalDeleted }

  var bytesCleaned: Int64 { bytesDeleted + bytesSavedByConversion + bytesSavedByTrimming }

  /// Kept photos left as they were; conversions are also counted in `totalKept`.
  var keptUnchanged: Int { max(totalKept - livePhotosConverted, 0) }

  /// `edited` counts edits written, which apply to photos whatever their decision.
  mutating func recordSession(kept: Int, deleted: Int, edited: Int, bytesDeleted: Int64) {
    startTrackingIfNeeded()
    totalKept += kept
    totalDeleted += deleted
    mediaEdited += edited
    self.bytesDeleted += bytesDeleted
    sessionsCompleted += 1
  }

  mutating func recordEdits(_ count: Int) {
    startTrackingIfNeeded()
    mediaEdited += count
  }

  mutating func recordLivePhotoConversion(bytesSaved: Int64) {
    startTrackingIfNeeded()
    livePhotosConverted += 1
    bytesSavedByConversion += bytesSaved
  }

  mutating func recordTrimSavings(bytes: Int64) {
    startTrackingIfNeeded()
    bytesSavedByTrimming += bytes
  }

  private mutating func startTrackingIfNeeded() {
    if trackingSince == nil { trackingSince = Date() }
  }
}

/// Decodes missing keys as zero so stats saved by earlier versions still load.
extension LifetimeSessionStats {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion =
      try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    totalKept = try container.decodeIfPresent(Int.self, forKey: .totalKept) ?? 0
    totalDeleted = try container.decodeIfPresent(Int.self, forKey: .totalDeleted) ?? 0
    bytesDeleted = try container.decodeIfPresent(Int64.self, forKey: .bytesDeleted) ?? 0
    livePhotosConverted = try container.decodeIfPresent(Int.self, forKey: .livePhotosConverted) ?? 0
    bytesSavedByConversion =
      try container.decodeIfPresent(Int64.self, forKey: .bytesSavedByConversion) ?? 0
    bytesSavedByTrimming =
      try container.decodeIfPresent(Int64.self, forKey: .bytesSavedByTrimming) ?? 0
    mediaEdited = try container.decodeIfPresent(Int.self, forKey: .mediaEdited) ?? 0
    sessionsCompleted = try container.decodeIfPresent(Int.self, forKey: .sessionsCompleted) ?? 0
    trackingSince = try container.decodeIfPresent(Date.self, forKey: .trackingSince)
  }
}

protocol LifetimeStatsServicing {
  func currentStats() -> LifetimeSessionStats
  @discardableResult
  func recordSession(kept: Int, deleted: Int, edited: Int, bytesDeleted: Int64)
    -> LifetimeSessionStats
  @discardableResult
  func recordLivePhotoConversion(bytesSaved: Int64) -> LifetimeSessionStats
  /// Adds edits written after their session was recorded.
  @discardableResult
  func recordEdits(_ count: Int) -> LifetimeSessionStats
  /// Adds the space freed by trimmed videos whose originals were deleted.
  @discardableResult
  func recordTrimSavings(bytes: Int64) -> LifetimeSessionStats
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
  func recordSession(kept: Int, deleted: Int, edited: Int, bytesDeleted: Int64)
    -> LifetimeSessionStats {
    var stats = currentStats()
    stats.recordSession(kept: kept, deleted: deleted, edited: edited, bytesDeleted: bytesDeleted)
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

  @discardableResult
  func recordEdits(_ count: Int) -> LifetimeSessionStats {
    var stats = currentStats()
    stats.recordEdits(count)
    save(stats)
    return stats
  }

  @discardableResult
  func recordTrimSavings(bytes: Int64) -> LifetimeSessionStats {
    var stats = currentStats()
    stats.recordTrimSavings(bytes: bytes)
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
    func recordSession(kept: Int, deleted: Int, edited: Int, bytesDeleted: Int64)
    -> LifetimeSessionStats {
      stats.recordSession(kept: kept, deleted: deleted, edited: edited, bytesDeleted: bytesDeleted)
      return stats
    }

    @discardableResult
    func recordLivePhotoConversion(bytesSaved: Int64) -> LifetimeSessionStats {
      stats.recordLivePhotoConversion(bytesSaved: bytesSaved)
      return stats
    }

    @discardableResult
    func recordEdits(_ count: Int) -> LifetimeSessionStats {
      stats.recordEdits(count)
      return stats
    }

    @discardableResult
    func recordTrimSavings(bytes: Int64) -> LifetimeSessionStats {
      stats.recordTrimSavings(bytes: bytes)
      return stats
    }

    func clear() { stats = LifetimeSessionStats() }
  }
#endif
