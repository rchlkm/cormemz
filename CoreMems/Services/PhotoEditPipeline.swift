// CoreMems/Services/PhotoEditPipeline.swift
import CoreImage
import UIKit

/// The pixel edits of a `MediaEdit`, applied to a photo. The editor's preview and the render
/// that Apply writes both run it, so they match. Rotation is applied separately.
nonisolated enum PhotoEditPipeline {
  /// Keeps one decoded image well inside the image cache's budget.
  private static let maxRequestPixels: CGFloat = 8_000_000

  private static let context = CIContext()

  static func apply(_ edit: MediaEdit, to image: CIImage) -> CIImage {
    guard let cropRect = edit.cropRect else { return image }
    let extent = image.extent
    // Core Image's origin is bottom-left; the crop's is top-left.
    let area = CGRect(
      x: extent.minX + cropRect.minX * extent.width,
      y: extent.minY + (1 - cropRect.maxY) * extent.height,
      width: cropRect.width * extent.width,
      height: cropRect.height * extent.height
    ).integral.intersection(extent)
    return image.cropped(to: area)
      .transformed(by: CGAffineTransform(translationX: -area.minX, y: -area.minY))
  }

  /// `image` with the edit's pixel changes, or itself when it has none.
  @concurrent
  static func apply(_ edit: MediaEdit, to image: UIImage) async -> UIImage {
    guard edit.changesPixels, let source = CIImage(image: image) else { return image }
    let result = apply(edit, to: source)
    guard
      let rendered = context.createCGImage(
        result, from: result.extent, format: .RGBA8, colorSpace: image.cgImage?.colorSpace)
    else { return image }
    return UIImage(cgImage: rendered, scale: image.scale, orientation: .up)
  }

  /// The pixel size to load a photo at so the edit's result still fills `size`: a crop
  /// shows only part of the photo, so the whole is loaded larger, up to a pixel budget.
  static func requestSize(for size: CGSize, edit: MediaEdit?) -> CGSize {
    guard let cropRect = edit?.cropRect, cropRect.width > 0, cropRect.height > 0 else {
      return size
    }
    let wanted = 1 / max(cropRect.width, cropRect.height)
    let affordable = (maxRequestPixels / max(size.width * size.height, 1)).squareRoot()
    let scale = max(1, min(wanted, affordable))
    return CGSize(width: size.width * scale, height: size.height * scale)
  }
}
