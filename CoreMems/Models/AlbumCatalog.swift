// CoreMems/Models/AlbumCatalog.swift
import Foundation

/// Every user album in the library (names and counts only), indexed by ID.
struct AlbumCatalog {
  /// `nil` until loaded.
  var albums: [AlbumOption]? {
    didSet {
      byID = Dictionary(
        (albums ?? []).map { ($0.ref.identifier, $0) }, uniquingKeysWith: { first, _ in first })
    }
  }
  private var byID: [String: AlbumOption] = [:]

  var isLoaded: Bool { albums != nil }

  /// The albums for `identifiers`, in that order, skipping any not in the catalog.
  func albums(withIdentifiers identifiers: [String]) -> [AlbumOption] {
    identifiers.compactMap { byID[$0] }
  }
}
