// CoreMemsTests/Support/SessionHarness.swift
import Foundation

@testable import CoreMems

/// A `SessionViewModel` wired to in-memory doubles.
@MainActor
struct SessionHarness {
  let vm: SessionViewModel
  let library: RecordingPhotoLibrary
  let persistence: MockSessionPersistence
  let haptics: MockHapticsService
  let stats: MockLifetimeStatsService
  let reviewedStore: ReviewedPhotosStore

  init(
    library: RecordingPhotoLibrary? = nil,
    persistence: MockSessionPersistence? = nil
  ) {
    let library = library ?? RecordingPhotoLibrary()
    let persistence = persistence ?? MockSessionPersistence()
    self.library = library
    self.persistence = persistence
    haptics = MockHapticsService()
    stats = MockLifetimeStatsService()
    reviewedStore = ReviewedPhotosStore(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("reviewed-\(UUID().uuidString).json"))
    vm = SessionViewModel(
      library: library,
      persistence: persistence,
      haptics: haptics,
      statsStore: stats,
      pinnedAlbumsStore: MockPinnedAlbumsStore(),
      reviewedPhotosStore: reviewedStore)
  }

  static func assetID(_ index: Int) -> String { "asset-\(index)" }

  /// The session photo ID a library asset gets when it is the `index`th photo of a session.
  static func photoID(_ index: Int) -> String { "asset-\(index)-\(index)" }

  /// A harness whose session is already under review, over `photoCount` library photos.
  /// `liveIndexes` are Live Photos; `sizes` maps an asset index to its reported bytes.
  /// `batchSize` overrides the check-in interval, which sets how many photos load per batch.
  static func started(
    photoCount: Int, liveIndexes: Set<Int> = [], sizes: [Int: Int64] = [:],
    batchSize: Int? = nil, mode: SelectionMode = .recent
  ) async -> SessionHarness {
    let library = RecordingPhotoLibrary()
    library.assets = (0..<photoCount).map {
      FakeAsset(identifier: assetID($0), isLive: liveIndexes.contains($0))
    }
    library.storageSizes = Dictionary(uniqueKeysWithValues: sizes.map { (assetID($0), $1) })
    let harness = SessionHarness(library: library)
    let originalInterval = harness.vm.checkInInterval
    if let batchSize { harness.vm.checkInInterval = batchSize }
    await harness.vm.startSession(mode: mode, startDate: nil)
    harness.vm.checkInInterval = originalInterval
    return harness
  }

  /// Decides on `index` and waits for the decision to be recorded.
  func decide(_ index: Int, _ decision: ReviewDecision) async {
    await vm.decide(index: index, decision: decision)?.value
  }
}
