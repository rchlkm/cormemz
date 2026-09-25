// CoreMemsTests/Services/PhotoImageLoaderTests.swift
import Testing
import UIKit

@testable import CoreMems

/// Stands in for Photos: each fetch takes `duration` and ends early, returning nil, when cancelled.
nonisolated private final class FakeImageFetcher: @unchecked Sendable {
  private let lock = NSLock()
  private var started = 0
  private var cancelled = 0
  private let duration: Duration

  init(duration: Duration) { self.duration = duration }

  var startedCount: Int { lock.withLock { started } }
  var cancelledCount: Int { lock.withLock { cancelled } }

  func fetch(_ identifier: String, _ size: CGSize) async -> UIImage? {
    lock.withLock { started += 1 }
    try? await Task.sleep(for: duration)
    if Task.isCancelled {
      lock.withLock { cancelled += 1 }
      return nil
    }
    return UIImage()
  }
}

@Suite("Loading photo images")
@MainActor
struct PhotoImageLoaderTests {
  private let size = CGSize(width: 100, height: 100)

  private func loader(duration: Duration) -> (PhotoImageLoader, FakeImageFetcher) {
    let fetcher = FakeImageFetcher(duration: duration)
    return (PhotoImageLoader { @Sendable in await fetcher.fetch($0, $1) }, fetcher)
  }

  @Test func concurrentRequestsForOneImageShareOneFetch() async {
    let (loader, fetcher) = loader(duration: .milliseconds(100))
    let size = size

    async let first = loader.image(for: "a", targetSize: size)
    async let second = loader.image(for: "a", targetSize: size)
    let images = await [first, second]

    #expect(images.allSatisfy { $0 != nil })
    #expect(fetcher.startedCount == 1)
  }

  @Test func aFinishedImageIsServedFromCache() async {
    let (loader, fetcher) = loader(duration: .milliseconds(10))

    _ = await loader.image(for: "a", targetSize: size)
    _ = await loader.image(for: "a", targetSize: size)

    #expect(fetcher.startedCount == 1)
  }

  @Test func differentSizesAreFetchedSeparately() async {
    let (loader, fetcher) = loader(duration: .milliseconds(10))

    _ = await loader.image(for: "a", targetSize: size)
    _ = await loader.image(for: "a", targetSize: CGSize(width: 200, height: 200))

    #expect(fetcher.startedCount == 2)
  }

  @Test func cancellingTheOnlyRequestCancelsTheFetch() async {
    let (loader, fetcher) = loader(duration: .seconds(30))
    let size = size

    let task = Task { await loader.image(for: "a", targetSize: size) }
    #expect(await eventually { fetcher.startedCount == 1 })
    task.cancel()

    #expect(await eventually { fetcher.cancelledCount == 1 })
    #expect(await task.value == nil)
  }

  @Test func cancellingOneOfTwoRequestsLetsTheOtherFinish() async {
    let (loader, fetcher) = loader(duration: .milliseconds(300))
    let size = size

    let cancelled = Task { await loader.image(for: "a", targetSize: size) }
    let kept = Task { await loader.image(for: "a", targetSize: size) }
    #expect(await eventually { fetcher.startedCount == 1 })
    cancelled.cancel()

    #expect(await kept.value != nil)
    #expect(fetcher.startedCount == 1)
    #expect(fetcher.cancelledCount == 0)
  }

  @Test func cancellingEveryRequestCancelsTheFetch() async {
    let (loader, fetcher) = loader(duration: .seconds(30))
    let size = size

    let first = Task { await loader.image(for: "a", targetSize: size) }
    let second = Task { await loader.image(for: "a", targetSize: size) }
    #expect(await eventually { fetcher.startedCount == 1 })
    first.cancel()
    second.cancel()

    #expect(await eventually { fetcher.cancelledCount == 1 })
  }

  @Test func aNewPrefetchCancelsTheStalePrefetchDownload() async {
    let (loader, fetcher) = loader(duration: .seconds(30))

    await loader.prefetchNext(identifier: "a", targetSize: size)
    #expect(await eventually { fetcher.startedCount == 1 })
    await loader.prefetchNext(identifier: "b", targetSize: size)

    #expect(await eventually { fetcher.cancelledCount == 1 })
    await loader.clearCache()
    #expect(await eventually { fetcher.cancelledCount == 2 })
  }
}
