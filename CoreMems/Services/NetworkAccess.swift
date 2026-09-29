// CoreMems/Services/NetworkAccess.swift
import Combine
import Network
import os

/// What the current network path offers, reduced to what download policy needs.
nonisolated struct NetworkConditions: Equatable {
  var isConnected: Bool
  var isExpensive: Bool
  var isConstrained: Bool

  init(isConnected: Bool, isExpensive: Bool, isConstrained: Bool) {
    self.isConnected = isConnected
    self.isExpensive = isExpensive
    self.isConstrained = isConstrained
  }

  init(path: NWPath) {
    self.init(
      isConnected: path.status == .satisfied,
      isExpensive: path.isExpensive,
      isConstrained: path.isConstrained)
  }
}

/// Shared copy for why downloads might be paused, so Settings and the in-browse notice
/// don't drift out of sync describing the same underlying reason.
nonisolated enum NetworkPauseReason {
  static let lowDataMode = "Low Data Mode is on for this network"
  static let notAllowed = "You're offline, or your download setting rules out this connection"
}

/// Where the app may download photos from iCloud. Low Data Mode always blocks downloads.
nonisolated enum NetworkPolicy: String, CaseIterable {
  case wifiAndCellular
  case wifiOnly
  case downloadedOnly

  func allowsDownloads(on conditions: NetworkConditions) -> Bool {
    switch self {
    case .wifiAndCellular:
      return conditions.isConnected && !conditions.isConstrained
    case .wifiOnly:
      return conditions.isConnected && !conditions.isExpensive && !conditions.isConstrained
    case .downloadedOnly:
      return false
    }
  }
}

/// Whether photos missing from the device may be downloaded right now.
nonisolated protocol NetworkAccessProviding: AnyObject, Sendable {
  var policy: NetworkPolicy { get set }
  var allowsDownloads: Bool { get }
  /// Whether iOS's Low Data Mode is active on the current network — this alone can be why
  /// `allowsDownloads` is false regardless of `policy`.
  var isConstrained: Bool { get }
  /// Emits the current value on subscription, then every change.
  var allowsDownloadsUpdates: AnyPublisher<Bool, Never> { get }
}

/// Combines the user's `NetworkPolicy` with live network conditions.
nonisolated final class NetworkMonitor: NetworkAccessProviding, @unchecked Sendable {
  static let shared = NetworkMonitor()

  private struct State {
    var policy = NetworkPolicy.wifiAndCellular
    var conditions = NetworkConditions(isConnected: true, isExpensive: false, isConstrained: false)
    var allowsDownloads: Bool { policy.allowsDownloads(on: conditions) }
  }

  private let state = OSAllocatedUnfairLock(initialState: State())
  private let subject = CurrentValueSubject<Bool, Never>(true)
  private let monitor = NWPathMonitor()
  private static let logger = Logger(subsystem: "com.coremems", category: "network")

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      self?.publish { $0.conditions = NetworkConditions(path: path) }
    }
    monitor.start(queue: DispatchQueue(label: "com.coremems.network-monitor"))
  }

  var policy: NetworkPolicy {
    get { state.withLock { $0.policy } }
    set { publish { $0.policy = newValue } }
  }

  var allowsDownloads: Bool {
    state.withLock { $0.allowsDownloads }
  }

  var isConstrained: Bool {
    state.withLock { $0.conditions.isConstrained }
  }

  var allowsDownloadsUpdates: AnyPublisher<Bool, Never> {
    subject.removeDuplicates().eraseToAnyPublisher()
  }

  /// Sends inside the lock so updates from different threads reach subscribers in order.
  /// No-ops (and skips the log) when neither the policy nor the conditions actually changed —
  /// `NWPathMonitor` fires on plenty of network churn that doesn't affect either.
  private func publish(_ change: (inout State) -> Void) {
    let changed: (policy: NetworkPolicy, conditions: NetworkConditions, allowsDownloads: Bool)? =
      state.withLockUnchecked { state in
        let previousPolicy = state.policy
        let previousConditions = state.conditions
        change(&state)
        guard state.policy != previousPolicy || state.conditions != previousConditions else {
          return nil
        }
        subject.send(state.allowsDownloads)
        return (state.policy, state.conditions, state.allowsDownloads)
      }
    guard let changed else { return }
    Self.logger.debug(
      "policy=\(String(describing: changed.policy), privacy: .public) connected=\(changed.conditions.isConnected, privacy: .public) expensive=\(changed.conditions.isExpensive, privacy: .public) constrained=\(changed.conditions.isConstrained, privacy: .public) allowsDownloads=\(changed.allowsDownloads, privacy: .public)"
    )
  }
}
