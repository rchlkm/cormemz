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

/// Stands in for Photos delivering `results` in order; with `finishes` false the stream stays open
/// until its consumer terminates it.
nonisolated private final class FakeProgressiveFetcher: @unchecked Sendable {
  private let lock = NSLock()
  private var started = 0
  private var terminated = 0
  private let results: [PhotoImageLoader.LoadedImage]
  private let finishes: Bool

  init(results: [PhotoImageLoader.LoadedImage], finishes: Bool = true) {
    self.results = results
    self.finishes = finishes
  }

  var startedCount: Int { lock.withLock { started } }
  var terminatedCount: Int { lock.withLock { terminated } }

  func fetch(_ identifier: String, _ size: CGSize) -> AsyncStream<PhotoImageLoader.LoadedImage> {
    lock.withLock { started += 1 }
    return AsyncStream { continuation in
      for result in results { continuation.yield(result) }
      if finishes { continuation.finish() }
      continuation.onTermination = { _ in self.lock.withLock { self.terminated += 1 } }
    }
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

  private func progressiveLoader(
    _ progressive: FakeProgressiveFetcher, duration: Duration = .milliseconds(10)
  ) -> (PhotoImageLoader, FakeImageFetcher) {
    let fetcher = FakeImageFetcher(duration: duration)
    let loader = PhotoImageLoader(
      fetch: { @Sendable in await fetcher.fetch($0, $1) },
      progressiveFetch: { @Sendable in progressive.fetch($0, $1) })
    return (loader, fetcher)
  }

  private func collect(_ stream: AsyncStream<PhotoImageLoader.LoadedImage>) async -> [Bool] {
    var degradedFlags: [Bool] = []
    for await loaded in stream { degradedFlags.append(loaded.isDegraded) }
    return degradedFlags
  }

  @Test func progressiveImagesYieldAStandInThenTheFinalImage() async {
    let progressive = FakeProgressiveFetcher(results: [
      .init(image: UIImage(), isDegraded: true), .init(image: UIImage(), isDegraded: false),
    ])
    let (loader, _) = progressiveLoader(progressive)

    let flags = await collect(loader.progressiveImages(for: "a", targetSize: size))

    #expect(flags == [true, false])
  }

  @Test func aFinalProgressiveImageIsCachedForLaterLoads() async {
    let progressive = FakeProgressiveFetcher(results: [.init(image: UIImage(), isDegraded: false)])
    let (loader, fetcher) = progressiveLoader(progressive)

    _ = await collect(loader.progressiveImages(for: "a", targetSize: size))
    let image = await loader.image(for: "a", targetSize: size)

    #expect(image != nil)
    #expect(fetcher.startedCount == 0)
  }

  @Test func aStandInAloneIsNotCached() async {
    let progressive = FakeProgressiveFetcher(results: [.init(image: UIImage(), isDegraded: true)])
    let (loader, fetcher) = progressiveLoader(progressive)

    _ = await collect(loader.progressiveImages(for: "a", targetSize: size))
    _ = await loader.image(for: "a", targetSize: size)

    #expect(fetcher.startedCount == 1)
  }

  @Test func aCachedImageIsYieldedAloneWithoutAnotherRequest() async {
    let progressive = FakeProgressiveFetcher(results: [.init(image: UIImage(), isDegraded: true)])
    let (loader, _) = progressiveLoader(progressive)
    _ = await loader.image(for: "a", targetSize: size)

    let flags = await collect(loader.progressiveImages(for: "a", targetSize: size))

    #expect(flags == [false])
    #expect(progressive.startedCount == 0)
  }

  @Test func stoppingAProgressiveConsumerEndsTheRequest() async {
    let progressive = FakeProgressiveFetcher(
      results: [.init(image: UIImage(), isDegraded: true)], finishes: false)
    let (loader, _) = progressiveLoader(progressive)
    let size = size

    let task = Task {
      for await _ in await loader.progressiveImages(for: "a", targetSize: size) {}
    }
    #expect(await eventually { progressive.startedCount == 1 })
    task.cancel()

    #expect(await eventually { progressive.terminatedCount == 1 })
  }
}
