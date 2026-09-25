// CoreMemsTests/Session/BatchLoadingTests.swift
import Testing

@testable import CoreMems

/// Serialized because starting a session with a custom batch size briefly changes the
/// persisted check-in interval.
@Suite("Loading photos in batches", .serialized)
@MainActor
struct BatchLoadingTests {
  private static let batchSize = 5
  private static let lookaheadBatches = 2
  private static let initialCount = batchSize * lookaheadBatches
  private static let settleTime: Duration = .milliseconds(100)

  private func started(photoCount: Int) async -> SessionHarness {
    await SessionHarness.started(photoCount: photoCount, batchSize: Self.batchSize)
  }

  private func requestedBatchSizes(_ h: SessionHarness) async -> [Int] {
    await h.library.lastSource?.requestedBatchSizes ?? []
  }

  @Test func sessionStartsWithTwoBatchesLoaded() async {
    let h = await started(photoCount: 40)

    #expect(h.vm.photos.count == Self.initialCount)
    #expect(await requestedBatchSizes(h) == [Self.initialCount])
  }

  @Test func anotherBatchLoadsOnceFewerThanTwoBatchesRemainAhead() async {
    let h = await started(photoCount: 40)

    await h.decide(0, .keep)

    #expect(await eventually { h.vm.photos.count == Self.initialCount + Self.batchSize })
    #expect(await requestedBatchSizes(h) == [Self.initialCount, Self.batchSize])
  }

  @Test func nothingLoadsWhileTwoBatchesRemainAhead() async {
    let h = await started(photoCount: 40)
    await h.decide(0, .keep)
    #expect(await eventually { h.vm.photos.count == 15 })

    for index in 1...4 { await h.decide(index, .keep) }
    try? await Task.sleep(for: Self.settleTime)

    #expect(h.vm.photos.count == 15)
    #expect(await requestedBatchSizes(h) == [Self.initialCount, Self.batchSize])

    await h.decide(5, .keep)

    #expect(await eventually { h.vm.photos.count == 20 })
    #expect(
      await requestedBatchSizes(h) == [Self.initialCount, Self.batchSize, Self.batchSize])
  }

  @Test func atLeastTwoBatchesStayAheadWhileTheLibraryLasts() async {
    let h = await started(photoCount: 40)

    for index in 0..<12 {
      await h.decide(index, .keep)
      #expect(await eventually { h.vm.photos.count - h.vm.currentIndex >= Self.initialCount })
    }
  }

  @Test func loadingStopsOnceTheLibraryRunsDry() async {
    let h = await started(photoCount: 12)

    await h.decide(0, .keep)
    #expect(await eventually { h.vm.photos.count == 12 })
    for index in 1..<12 { await h.decide(index, .keep) }
    try? await Task.sleep(for: Self.settleTime)

    #expect(await requestedBatchSizes(h) == [Self.initialCount, Self.batchSize])
    #expect(h.vm.screen == .pendingReview)
  }

  @Test func aSmallLibraryNeedsNoFurtherBatches() async {
    let h = await started(photoCount: 8)

    for index in 0..<8 { await h.decide(index, .keep) }
    try? await Task.sleep(for: Self.settleTime)

    #expect(h.vm.photos.count == 8)
    #expect(await requestedBatchSizes(h) == [Self.initialCount])
    #expect(h.vm.screen == .pendingReview)
  }

  @Test func sessionEndsOnceTheLastBatchComesBackEmpty() async {
    let h = await started(photoCount: Self.initialCount)

    for index in 0..<Self.initialCount { await h.decide(index, .keep) }

    #expect(await eventually { h.vm.screen == .pendingReview })
    #expect(await requestedBatchSizes(h).last == Self.batchSize)
  }

  @Test func aSessionNeverLoadsPastItsPhotoCap() async {
    let cap = SessionSettings.maxPhotosPerSession
    let h = await SessionHarness.started(photoCount: cap + 100, batchSize: 50)

    for index in 0..<cap {
      await h.decide(index, .keep)
      try? await Task.sleep(for: .milliseconds(1))
    }

    #expect(await eventually { h.vm.screen == .pendingReview })
    #expect(h.vm.photos.count == cap)
    #expect(h.vm.reachedSessionCap)
  }

  @Test func endingEarlyIsNotTheSessionCap() async {
    let h = await started(photoCount: 40)

    h.vm.finishEarly()

    #expect(!h.vm.reachedSessionCap)
  }
}
