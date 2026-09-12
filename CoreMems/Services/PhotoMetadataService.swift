// CoreMems/Services/PhotoMetadataService.swift

import Foundation
import ImageIO
import Photos

protocol PhotoMetadataServicing {
  func fetchMetadata(for asset: PHAsset) async -> PhotoMetadata
}

/// Pulls together everything PhotoKit exposes about a single asset:
/// basic PHAsset fields, the underlying PHAssetResource (filename,
/// file size, format), and the image's embedded EXIF/TIFF/GPS
/// dictionaries (camera, lens, exposure) via a content-editing input.
final class PhotoMetadataService: PhotoMetadataServicing {

  func fetchMetadata(for asset: PHAsset) async -> PhotoMetadata {
    var metadata = PhotoMetadata(
      creationDate: asset.creationDate,
      modificationDate: asset.modificationDate,
      pixelWidth: asset.pixelWidth,
      pixelHeight: asset.pixelHeight,
      isFavorite: asset.isFavorite,
      latitude: asset.location?.coordinate.latitude,
      longitude: asset.location?.coordinate.longitude
    )

    let resources = PHAssetResource.assetResources(for: asset)
    if let resource = resources.first(where: { $0.type == .photo }) ?? resources.first {
      metadata.originalFilename = resource.originalFilename
      metadata.uniformTypeIdentifier = resource.uniformTypeIdentifier
      // No public API for resource file size pre-iOS 14; this KVC
      // lookup is the commonly-used fallback and just degrades to
      // `nil` (handled gracefully by the sheet UI) if it ever breaks.
      metadata.fileSizeBytes = resource.value(forKey: "fileSize") as? Int64
    }

    if let exifProperties = await fetchImageProperties(for: asset) {
      if let tiff = exifProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
        metadata.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
        metadata.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
      }
      if let exif = exifProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
        metadata.lensModel = exif[kCGImagePropertyExifLensModel as String] as? String
        metadata.fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double
        metadata.exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double
        metadata.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double
        metadata.focalLength35mm = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Int
        if let isoRatings = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber] {
          metadata.isoSpeed = isoRatings.first?.intValue
        }
      }
    }

    return metadata
  }

  /// EXIF/TIFF/GPS live on the *image file*, not on PHAsset directly —
  /// a content-editing input is the supported way to get at the
  /// original file URL (and will pull it down from iCloud if needed).
  private func fetchImageProperties(for asset: PHAsset) async -> [String: Any]? {
    await withCheckedContinuation { continuation in
      let options = PHContentEditingInputRequestOptions()
      options.isNetworkAccessAllowed = true
      asset.requestContentEditingInput(with: options) { input, _ in
        guard
          let url = input?.fullSizeImageURL,
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: properties)
      }
    }
  }
}
