import CoreLocation
import Foundation
import UniformTypeIdentifiers

/// Full EXIF-style metadata for a single reviewed photo, shown in the
/// pull-up "Photo Details" sheet. Populated from `PHAsset` +
/// `PHAssetResource` + the image's embedded EXIF/TIFF/GPS dictionaries
/// for real photos (see `PhotoMetadataService`), or synthesized from
/// `SessionPhoto` fields alone for mock/preview data where there's no
/// real `PHAsset` to inspect (empty-library demo, SwiftUI previews).
struct PhotoMetadata: Equatable {
  var creationDate: Date?
  var modificationDate: Date?
  var pixelWidth: Int?
  var pixelHeight: Int?
  var fileSizeBytes: Int64?
  var originalFilename: String?
  var uniformTypeIdentifier: String?
  var isFavorite: Bool = false

  var latitude: Double?
  var longitude: Double?

  var cameraMake: String?
  var cameraModel: String?
  var lensModel: String?
  var fNumber: Double?
  var exposureTime: Double?
  var isoSpeed: Int?
  var focalLength: Double?
  var focalLength35mm: Int?

  var hasCameraInfo: Bool {
    cameraMake != nil || cameraModel != nil || lensModel != nil || fNumber != nil
      || exposureTime != nil || isoSpeed != nil
  }

  var coordinate: CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  var mapsURL: URL? {
    guard let latitude, let longitude else { return nil }
    return URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)")
  }

  // MARK: Formatted display strings

  var formattedDate: String? {
    guard let creationDate else { return nil }
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    return formatter.string(from: creationDate)
  }

  var formattedDimensions: String? {
    guard let pixelWidth, let pixelHeight, pixelWidth > 0, pixelHeight > 0 else { return nil }
    return "\(pixelWidth) × \(pixelHeight) px"
  }

  var formattedFileSize: String? {
    guard let fileSizeBytes else { return nil }
    return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
  }

  var formattedFormat: String? {
    guard let uniformTypeIdentifier else { return nil }
    if let type = UTType(uniformTypeIdentifier) {
      return type.preferredFilenameExtension?.uppercased() ?? type.localizedDescription
    }
    return uniformTypeIdentifier
  }

  var formattedCamera: String? {
    let parts = [cameraMake, cameraModel].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
  }

  var formattedAperture: String? {
    guard let fNumber else { return nil }
    return "f/\(String(format: "%.1f", fNumber))"
  }

  var formattedShutterSpeed: String? {
    guard let exposureTime, exposureTime > 0 else { return nil }
    if exposureTime < 1 {
      return "1/\(Int((1 / exposureTime).rounded())) s"
    }
    return "\(String(format: "%.1f", exposureTime)) s"
  }

  var formattedISO: String? {
    guard let isoSpeed else { return nil }
    return "ISO \(isoSpeed)"
  }

  var formattedFocalLength: String? {
    guard let focalLength else { return nil }
    let base = "\(Int(focalLength.rounded())) mm"
    if let focalLength35mm {
      return "\(base) (\(focalLength35mm) mm equiv.)"
    }
    return base
  }

  var formattedCoordinate: String? {
    guard let latitude, let longitude else { return nil }
    return String(format: "%.5f, %.5f", latitude, longitude)
  }

  /// Best-effort metadata for mock/preview `SessionPhoto`s that have
  /// no backing `PHAsset` (empty-library demo, SwiftUI previews) —
  /// only fields derivable from the photo itself are filled in.
  static func placeholder(for photo: SessionPhoto) -> PhotoMetadata {
    var metadata = PhotoMetadata()
    metadata.isFavorite = photo.isFavorite
    if !photo.dateLabel.isEmpty {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMM d, yyyy"
      metadata.creationDate = formatter.date(from: photo.dateLabel)
    }
    return metadata
  }
}
