// CoreMems/Extensions/URL+FileSize.swift
import Foundation

extension URL {
  /// The file's size in bytes, or `nil` when it can't be read.
  var fileSize: Int64? {
    (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
  }
}
