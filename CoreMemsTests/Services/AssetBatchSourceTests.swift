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
  @Test func screenshotsFilterRestrictsToTheScreenshotSubtype() {
    let format = AssetBatchSource.mediaTypePredicate(.screenshots).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("!= 0"))
  }

  @Test func photosFilterExcludesTheScreenshotSubtype() {
    let format = AssetBatchSource.mediaTypePredicate(.photos).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("== 0"))
  }

  @Test func allFilterDoesNotRestrictBySubtype() {
    #expect(!AssetBatchSource.mediaTypePredicate(.all).predicateFormat.contains("mediaSubtypes"))
  }

  @Test func videosFilterExcludesTheTimelapseSubtype() {
    let format = AssetBatchSource.mediaTypePredicate(.videos).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("== 0"))
  }

  @Test func timelapsesFilterRestrictsToTheTimelapseSubtype() {
    let format = AssetBatchSource.mediaTypePredicate(.timelapses).predicateFormat
    #expect(format.contains("mediaSubtypes"))
    #expect(format.contains("!= 0"))
  }
}
