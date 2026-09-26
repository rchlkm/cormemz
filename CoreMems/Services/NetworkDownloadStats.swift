// CoreMems/Services/NetworkDownloadStats.swift
#if DEBUG
  import Combine
  import Photos
  import os

  /// Session totals for photos Photos had to download from iCloud. PhotoKit reports no byte
  /// counts, so sizes are the originals' sizes: an upper bound on what was transferred.
  @MainActor
  final class NetworkDownloadStats: ObservableObject {
    static let shared = NetworkDownloadStats()

    private static let logger = Logger(subsystem: "com.coremems", category: "network")

    @Published private(set) var downloadCount = 0
    @Published private(set) var estimatedBytes: Int64 = 0

    nonisolated static func recordDownload(of asset: PHAsset) {
      let bytes = PhotoLibraryService.fileSize(of: asset) ?? 0
      Task { @MainActor in shared.record(bytes: bytes) }
    }

    func record(bytes: Int64) {
      downloadCount += 1
      estimatedBytes += bytes
      Self.logger.debug("iCloud download #\(self.downloadCount), up to \(bytes) bytes")
    }

    func reset() {
      downloadCount = 0
      estimatedBytes = 0
    }
  }

  /// Photos calls a request's progress handler only while it transfers over the network.
  nonisolated final class NetworkTransferProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var transferred = false

    var didTransfer: Bool { lock.withLock { transferred } }

    func markTransferred() { lock.withLock { transferred = true } }
  }
#endif
