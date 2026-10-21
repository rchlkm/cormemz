// CoreMemsTests/Services/PhotoEditPipelineTests.swift
import CoreImage
import Testing
import UIKit

@testable import CoreMems

@Suite("Photo edit pipeline")
struct PhotoEditPipelineTests {
  private let red = [UInt8]([255, 0, 0])
  private let green = [UInt8]([0, 255, 0])
  private let blue = [UInt8]([0, 0, 255])

  /// Four one-pixel-wide, two-pixel-tall columns: red, green, blue, white.
  private var columns: CIImage {
    [CIColor.red, .green, .blue, .white].enumerated().reduce(
      CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 2))
    ) { image, column in
      CIImage(color: column.element)
        .cropped(to: CGRect(x: column.offset, y: 0, width: 1, height: 2))
        .composited(over: image)
    }
  }

  @Test func anEditWithoutACropLeavesTheImageAlone() {
    let result = PhotoEditPipeline.apply(MediaEdit(), to: columns)

    #expect(result.extent == CGRect(x: 0, y: 0, width: 4, height: 2))
  }

  @Test func aSquareCropKeepsTheMiddleAtTheOrigin() {
    var edit = MediaEdit()
    edit.crop(to: .square, ofSourceSize: CGSize(width: 4, height: 2))

    let result = PhotoEditPipeline.apply(edit, to: columns)

    #expect(result.extent == CGRect(x: 0, y: 0, width: 2, height: 2))
    #expect(result.pixel(at: CGPoint(x: 0, y: 0)) == green)
    #expect(result.pixel(at: CGPoint(x: 1, y: 0)) == blue)
  }

  @Test func theCropIsMeasuredFromTheTopLeft() {
    // A 2 x 2 image: red on top, blue below.
    let top = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 1, width: 2, height: 1))
    let bottom = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 1))
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0, width: 1, height: 0.5)

    let result = PhotoEditPipeline.apply(edit, to: top.composited(over: bottom))

    #expect(result.extent == CGRect(x: 0, y: 0, width: 2, height: 1))
    #expect(result.pixel(at: .zero) == red)
  }

  @Test func aRotatedEditStillCropsTheSameSourceArea() {
    var edit = MediaEdit()
    edit.rotate()
    edit.displayedCropRect = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)

    let result = PhotoEditPipeline.apply(edit, to: columns)

    // Turned, the bottom half is the left half of the source.
    #expect(result.extent == CGRect(x: 0, y: 0, width: 2, height: 2))
    #expect(result.pixel(at: CGPoint(x: 0, y: 0)) == red)
    #expect(result.pixel(at: CGPoint(x: 1, y: 0)) == green)
  }

  @Test func aCroppedUIImageHasTheCroppedSize() async {
    let size = CGSize(width: 40, height: 20)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
    var edit = MediaEdit()
    edit.crop(to: .square, ofSourceSize: size)

    let result = await PhotoEditPipeline.apply(edit, to: image)

    #expect(result.size == CGSize(width: 20, height: 20))
  }

  @Test func anUncroppedUIImageIsReturnedAsIs() async {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2)).image { _ in }

    let result = await PhotoEditPipeline.apply(MediaEdit(), to: image)

    #expect(result === image)
  }

  @Test func withoutACropTheRequestKeepsItsSize() {
    let size = CGSize(width: 800, height: 600)

    #expect(PhotoEditPipeline.requestSize(for: size, edit: nil) == size)
    #expect(PhotoEditPipeline.requestSize(for: size, edit: MediaEdit()) == size)
  }

  @Test func aCropRequestsTheWholePhotoLargerInProportion() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)

    let size = PhotoEditPipeline.requestSize(for: CGSize(width: 800, height: 600), edit: edit)

    #expect(size == CGSize(width: 1600, height: 1200))
  }

  @Test func theLongerSideOfTheCropSetsTheEnlargement() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0.125, width: 1, height: 0.75)

    let size = PhotoEditPipeline.requestSize(for: CGSize(width: 800, height: 800), edit: edit)

    #expect(size == CGSize(width: 800, height: 800))
  }

  @Test func aTinyCropIsRequestedWithinThePixelBudget() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0, y: 0, width: 0.05, height: 0.05)

    let size = PhotoEditPipeline.requestSize(for: CGSize(width: 1000, height: 1000), edit: edit)

    #expect(size.width * size.height <= 8_000_000 + 1)
    #expect(size.width > 1000)
  }
}
