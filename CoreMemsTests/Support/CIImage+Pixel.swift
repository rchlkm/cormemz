// CoreMemsTests/Support/CIImage+Pixel.swift
import CoreImage

extension CIImage {
  /// The red, green and blue bytes at `point`, read without colour management.
  func pixel(at point: CGPoint) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    context.render(
      self, toBitmap: &rgba, rowBytes: 4,
      bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBA8,
      colorSpace: nil)
    return Array(rgba.prefix(3))
  }
}
