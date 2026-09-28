// CoreMemsTests/Services/FilteringAssetSourceTests.swift
import Foundation
import Photos
import Testing
import os

@testable import CoreMems

@Suite("Filtering an asset source")
struct FilteringAssetSourceTests {
  private func assets(_ count: Int) -> [PHAsset] {
    (0..<count).map { FakeAsset(identifier: "asset-\($0)") }
  }

  private func identifiers(_ batch: [PHAsset]) -> [String] {
    batch.map(\.localIdentifier)
  }

  @Test func passesOnlyAdmittedAssets() async {
    let source = FilteringAssetSource(base: FakeAssetSource(assets: assets(6))) {
      $0.localIdentifier != "asset-1" && $0.localIdentifier != "asset-4"
    }

    let batch = await source.nextBatch(count: 6)

    #expect(identifiers(batch) == ["asset-0", "asset-2", "asset-3", "asset-5"])
  }

  @Test func refillsABatchFromBeyondSkippedAssets() async {
    let base = FakeAssetSource(assets: assets(9))
    let source = FilteringAssetSource(base: base) {
      Int($0.localIdentifier.dropFirst("asset-".count)).map { $0 % 3 == 0 } ?? false
    }

    let first = await source.nextBatch(count: 2)
    let second = await source.nextBatch(count: 2)

    #expect(identifiers(first) == ["asset-0", "asset-3"])
    #expect(identifiers(second) == ["asset-6"])
  }

  @Test func stopsOnceTheBaseRunsDry() async {
    let base = FakeAssetSource(assets: assets(4))
    let source = FilteringAssetSource(base: base) { _ in false }

    #expect(await source.nextBatch(count: 3).isEmpty)
    #expect(await source.nextBatch(count: 3).isEmpty)
    #expect(await base.requestedBatchSizes == [3, 3])
  }

  @Test func decidesAdmissionWhenTheBatchIsRequested() async {
    let admitting = OSAllocatedUnfairLock(initialState: true)
    let source = FilteringAssetSource(base: FakeAssetSource(assets: assets(4))) { _ in
      admitting.withLock { $0 }
    }

    let whileAdmitting = await source.nextBatch(count: 2)
    admitting.withLock { $0 = false }
    let whileRefusing = await source.nextBatch(count: 2)

    #expect(identifiers(whileAdmitting) == ["asset-0", "asset-1"])
    #expect(whileRefusing.isEmpty)
  }
}
