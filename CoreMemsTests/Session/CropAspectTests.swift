// CoreMemsTests/Session/CropAspectTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Crop aspects")
struct CropAspectTests {
  private let landscape = CGSize(width: 4000, height: 3000)
  private let portrait = CGSize(width: 3000, height: 4000)

  @Test func originalKeepsTheWholeImage() {
    #expect(CropAspect.original.displayedRect(in: landscape) == .wholeImage)
  }

  @Test func squareIsTheLargestCentredSquare() {
    #expect(
      CropAspect.square.displayedRect(in: landscape)
        == CGRect(x: 0.125, y: 0, width: 0.75, height: 1))
    #expect(
      CropAspect.square.displayedRect(in: portrait)
        == CGRect(x: 0, y: 0.125, width: 1, height: 0.75))
  }

  @Test func widerAspectsLoseTheTopAndBottomOfALandscapeImage() {
    let rect = CropAspect.sixteenNine.displayedRect(in: landscape)

    #expect(rect.width == 1)
    #expect(abs(rect.height * 3000 - 4000 * 9 / 16) < 1e-6)
    #expect(abs(rect.midY - 0.5) < 1e-9)
  }

  @Test func aPortraitImageGetsThePortraitShape() {
    let rect = CropAspect.threeTwo.displayedRect(in: portrait)

    #expect(rect.height == 1)
    #expect(abs(rect.width * 3000 - 4000 * 2 / 3) < 1e-6)
  }

  @Test func anImageAlreadyThatShapeIsLeftWhole() {
    #expect(CropAspect.fourThree.displayedRect(in: landscape).covers(.wholeImage))
    #expect(CropAspect.square.displayedRect(in: CGSize(width: 5, height: 5)).covers(.wholeImage))
  }

  @Test func everyAspectStaysWithinTheImage() {
    for aspect in CropAspect.allCases {
      for size in [landscape, portrait, CGSize(width: 100, height: 100)] {
        #expect(CGRect.wholeImage.covers(aspect.displayedRect(in: size)))
      }
    }
  }

  @Test func theCurrentAspectIsFoundFromTheEdit() {
    let wide = CGSize(width: 4000, height: 2000)
    for turns in 0..<4 {
      for aspect in CropAspect.allCases {
        var edit = MediaEdit()
        (0..<turns).forEach { _ in edit.rotate() }
        edit.crop(to: aspect, ofSourceSize: wide)

        #expect(CropAspect.matching(edit, sourceSize: wide) == aspect)
      }
    }
  }

  @Test func aCropOfNoAspectMatchesNone() {
    var edit = MediaEdit()
    edit.displayedCropRect = CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.6)

    #expect(CropAspect.matching(edit, sourceSize: landscape) == nil)
  }
}
