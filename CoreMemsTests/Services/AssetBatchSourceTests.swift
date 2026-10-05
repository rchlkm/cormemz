// CoreMemsTests/Services/AssetBatchSourceTests.swift
import Foundation
import Testing

@testable import CoreMems

@Suite("Asset batch source date ceiling")
struct AssetBatchSourceTests {
  private let calendar = Calendar.current

  @Test func aDateIncludesEverythingThroughTheEndOfItsDay() {
    let earlyMorning = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 6))!
    let lateEvening = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 21, minute: 30))!
    let nextMidnight = calendar.date(from: DateComponents(year: 2024, month: 6, day: 16))!

    #expect(AssetBatchSource.dateCeiling(for: earlyMorning) == nextMidnight)
    #expect(AssetBatchSource.dateCeiling(for: lateEvening) == nextMidnight)
  }

  @Test func noDateMeansNoCeiling() {
    #expect(AssetBatchSource.dateCeiling(for: nil) == .distantFuture)
  }
}

@Suite("Asset batch source media type predicate")
struct AssetBatchSourceMediaTypePredicateTests {
  private func subpredicates(_ types: Set<MediaType>) -> [NSPredicate] {
    let predicate = AssetBatchSource.mediaTypePredicate(types) as? NSCompoundPredicate
    #expect(predicate?.compoundPredicateType == .or)
    return predicate?.subpredicates.compactMap { $0 as? NSPredicate } ?? []
  }

  @Test func screenshotsRestrictToTheScreenshotSubtype() {
    let format = AssetBatchSource.mediaTypePredicate([.screenshots]).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("!= 0"))
  }

  @Test func photosExcludeTheScreenshotSubtype() {
    let format = AssetBatchSource.mediaTypePredicate([.photos]).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("== 0"))
  }

  @Test func videosExcludeTheTimelapseSubtype() {
    let format = AssetBatchSource.mediaTypePredicate([.videos]).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("== 0"))
  }

  @Test func timelapsesRestrictToTheTimelapseSubtype() {
    let format = AssetBatchSource.mediaTypePredicate([.timelapses]).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("!= 0"))
  }

  @Test func eachSelectedTypeContributesOneAlternative() {
    #expect(subpredicates([.photos]).count == 1)
    #expect(subpredicates([.photos, .videos]).count == 2)
    #expect(subpredicates([.photos, .screenshots, .videos]).count == 3)
  }

  @Test func noSelectionIsEveryPhotoAndVideo() {
    let format = AssetBatchSource.mediaTypePredicate([]).predicateFormat
    #expect(format.contains("mediaType"))
    #expect(!format.contains("mediaSubtypes"))
    #expect(
      AssetBatchSource.mediaTypePredicate([])
        == AssetBatchSource.mediaTypePredicate(Set(MediaType.allCases)))
  }

  @Test func theSameSelectionAlwaysBuildsTheSamePredicate() {
    #expect(
      AssetBatchSource.mediaTypePredicate([.videos, .photos])
        == AssetBatchSource.mediaTypePredicate([.photos, .videos]))
  }
}
