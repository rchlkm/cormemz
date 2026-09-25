// CoreMemsTests/Services/SessionSettingsTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Session settings and recent albums")
struct SessionSettingsTests {
  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "test-\(UUID().uuidString)")!
  }

  @Test func settingsFallBackToDefaultsWhenNothingIsStored() {
    let settings = SessionSettings(defaults: makeDefaults())

    #expect(settings.checkInInterval == SessionSettings.defaultCheckInInterval)
    #expect(!settings.includesReviewedPhotos)
  }

  @Test func settingsPersistAcrossInstances() {
    let defaults = makeDefaults()
    var settings = SessionSettings(defaults: defaults)

    settings.checkInInterval = 30
    settings.includesReviewedPhotos = true

    let reloaded = SessionSettings(defaults: defaults)
    #expect(reloaded.checkInInterval == 30)
    #expect(reloaded.includesReviewedPhotos)
  }

  @Test func aStoredIntervalOutsideTheRangeIsClamped() {
    let defaults = makeDefaults()
    defaults.set(500, forKey: "cm_checkInInterval")

    #expect(SessionSettings(defaults: defaults).checkInInterval == SessionSettings.checkInIntervalRange.upperBound)
  }

  @Test func recentAlbumsListNewestFirstWithoutDuplicates() {
    var recents = RecentAlbums(defaults: makeDefaults())

    recents.record("a")
    recents.record("b")
    recents.record("a")

    #expect(recents.ids == ["a", "b"])
  }

  @Test func recentAlbumsAreCappedAtTheLimit() {
    var recents = RecentAlbums(defaults: makeDefaults())

    for i in 0..<(RecentAlbums.limit + 3) { recents.record("album-\(i)") }

    #expect(recents.ids.count == RecentAlbums.limit)
    #expect(recents.ids.first == "album-\(RecentAlbums.limit + 2)")
  }

  @Test func persistingSkipsSessionLocalAlbums() {
    let defaults = makeDefaults()
    var recents = RecentAlbums(defaults: defaults)
    recents.record("real")
    recents.record("temp")

    recents.persist(excluding: ["temp"])

    #expect(RecentAlbums(defaults: defaults).ids == ["real"])
  }

  @Test func forgettingRemovesOnlyTheGivenAlbums() {
    var recents = RecentAlbums(defaults: makeDefaults())
    recents.record("a")
    recents.record("b")
    recents.record("c")

    recents.forget(["b"])

    #expect(recents.ids == ["c", "a"])
  }
}
