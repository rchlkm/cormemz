// CoreMemsTests/Session/EditFailureSimulationTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Edit failure simulation", .serialized)
@MainActor
struct EditFailureSimulationTests {
  private func withMode(_ mode: EditFailureSimulation.Mode, _ body: () -> Void) {
    let previous = UserDefaults.standard.string(forKey: EditFailureSimulation.key)
    UserDefaults.standard.set(mode.rawValue, forKey: EditFailureSimulation.key)
    body()
    UserDefaults.standard.set(previous, forKey: EditFailureSimulation.key)
  }

  @Test func offNeverFails() {
    withMode(.off) {
      #expect(!EditFailureSimulation.shouldFail(assetIdentifier: "off-a"))
    }
  }

  @Test func firstTryFailsEachAssetOnce() {
    withMode(.once) {
      #expect(EditFailureSimulation.shouldFail(assetIdentifier: "once-a"))
      #expect(!EditFailureSimulation.shouldFail(assetIdentifier: "once-a"))
      #expect(EditFailureSimulation.shouldFail(assetIdentifier: "once-b"))
    }
  }

  @Test func everyTryAlwaysFails() {
    withMode(.always) {
      #expect(EditFailureSimulation.shouldFail(assetIdentifier: "always-a"))
      #expect(EditFailureSimulation.shouldFail(assetIdentifier: "always-a"))
    }
  }
}
