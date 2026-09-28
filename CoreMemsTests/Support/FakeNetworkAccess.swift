// CoreMemsTests/Support/FakeNetworkAccess.swift
import Combine

@testable import CoreMems

/// Network access whose availability the test flips directly.
nonisolated final class FakeNetworkAccess: NetworkAccessProviding, @unchecked Sendable {
  private let subject: CurrentValueSubject<Bool, Never>

  var policy = NetworkPolicy.wifiAndCellular
  var isConstrained = false
  var allowsDownloads: Bool { subject.value }
  var allowsDownloadsUpdates: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

  init(allowsDownloads: Bool = true) {
    subject = CurrentValueSubject(allowsDownloads)
  }

  func setAllowsDownloads(_ allowed: Bool) {
    subject.send(allowed)
  }
}
