// CoreMems/Models/SessionFilters.swift
import Foundation

/// The choices a session was started with, as Home shows them.
struct SessionFilters: Codable, Equatable {
  struct Album: Codable, Equatable {
    let ref: AlbumRef
    let name: String

    init(_ option: AlbumOption) {
      ref = option.ref
      name = option.name
    }

    var option: AlbumOption { AlbumOption(ref: ref, name: name) }
  }

  var mode: SelectionMode
  var startDate: Date?
  var album: Album?
  var mediaTypes: Set<MediaType>
}
