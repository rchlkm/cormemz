// CoreMems/Models/AlbumCatalog.swift
import Foundation

/// Every user album in the library (names and counts only), indexed by ID.
struct AlbumCatalog {
  /// `nil` until loaded.
  var albums: [AlbumOption]? {
    didSet {
      byID = (albums ?? []).indexed(by: \.ref.identifier)
    }
  }
  private var byID: [String: AlbumOption] = [:]

  /// Photos folders that hold at least one album, at any depth.
  var groups: [AlbumGroup] = []

  var isLoaded: Bool { albums != nil }

  /// The albums for `identifiers`, in that order, skipping any not in the catalog.
  func albums(withIdentifiers identifiers: [String]) -> [AlbumOption] {
    identifiers.compactMap { byID[$0] }
  }
}
