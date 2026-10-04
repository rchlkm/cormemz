// CoreMems/Models/FailedEdit.swift
import Foundation

/// Why an edit couldn't be saved.
nonisolated enum EditFailureReason: Error, Hashable {
  /// The original is in iCloud and downloads aren't allowed right now.
  case needsDownload
  /// The Photos permission prompt was declined.
  case declined
  case unknown
}

/// An edit Apply couldn't save, kept so it can be retried or discarded.
struct FailedEdit: Identifiable {
  var photo: SessionPhoto
  var reason: EditFailureReason
  var attempts = 1
  var id: String { photo.id }
}
