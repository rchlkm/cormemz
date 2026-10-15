// CoreMemsTests/Session/VideoPlaybackSpeedTests.swift
import Testing

@testable import CoreMems

@Suite("Video playback speed")
struct VideoPlaybackSpeedTests {
  @Test func playsAtNormalSpeedByDefault() {
    let playback = VideoPlayback()

    #expect(playback.rate == 1)
  }

  @Test func holdingSpeedsUpUntilReleased() {
    let playback = VideoPlayback()

    playback.setSpeedHeld(true)
    #expect(playback.rate == VideoPlayback.fastRate)

    playback.setSpeedHeld(false)
    #expect(playback.rate == 1)
  }

  @Test func lockKeepsTheSpeedUntilToggledOff() {
    let playback = VideoPlayback()

    playback.toggleSpeedLock()
    #expect(playback.rate == VideoPlayback.fastRate)

    playback.toggleSpeedLock()
    #expect(playback.rate == 1)
  }

  @Test func releasingAHoldKeepsALockedSpeed() {
    let playback = VideoPlayback()
    playback.toggleSpeedLock()

    playback.setSpeedHeld(true)
    playback.setSpeedHeld(false)

    #expect(playback.rate == VideoPlayback.fastRate)
  }
}
