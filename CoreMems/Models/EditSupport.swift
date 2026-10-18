// CoreMems/Models/EditSupport.swift
import CoreGraphics

/// Which tools can change a photo or video.
struct EditSupport: Equatable {
  var trim = TrimSupport.unavailable
  /// The pixel size of a still photo, which can be cropped; `nil` for videos and Live Photos.
  var stillSize: CGSize?

  /// Why the media can't be cropped, or `nil` when it can.
  var cropNotice: String? {
    stillSize == nil ? "Only still photos can be cropped" : nil
  }
}
