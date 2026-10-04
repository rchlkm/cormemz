// CoreMemsTests/Views/HomeFilterTests.swift
import Testing

@testable import CoreMems

@Suite("Home filter title")
struct HomeFilterTitleTests {
  @Test func noFiltersIsJustFilters() {
    #expect(HomeView.filterTitle(mediaTypes: [], includesKeptPhotos: false) == "Filters")
  }

  @Test func aLoneMediaTypeIsNamed() {
    #expect(HomeView.filterTitle(mediaTypes: [.videos], includesKeptPhotos: false) == "Videos")
  }

  @Test func pastKeepsAloneIsNamed() {
    #expect(
      HomeView.filterTitle(mediaTypes: [], includesKeptPhotos: true) == "Include past keeps")
  }

  @Test func severalMediaTypesAreCounted() {
    #expect(
      HomeView.filterTitle(mediaTypes: [.photos, .videos], includesKeptPhotos: false)
        == "2 filters")
  }

  @Test func pastKeepsCountsAlongsideMediaTypes() {
    #expect(
      HomeView.filterTitle(mediaTypes: [.screenshots], includesKeptPhotos: true) == "2 filters")
  }
}

@Suite("Home media selection")
struct HomeMediaSelectionTests {
  @Test func turningATypeOnAddsIt() {
    #expect(HomeView.updatedSelection([.photos], setting: .videos, to: true) == [.photos, .videos])
  }

  @Test func turningATypeOffRemovesIt() {
    #expect(HomeView.updatedSelection([.photos, .videos], setting: .videos, to: false) == [.photos])
  }

  @Test func turningOffTheLastTypeLeavesNoSelection() {
    #expect(HomeView.updatedSelection([.videos], setting: .videos, to: false) == [])
  }

  @Test func selectingEveryTypeCollapsesToNoSelection() {
    let allButTimelapses: Set<MediaType> = [.photos, .screenshots, .videos]
    #expect(HomeView.updatedSelection(allButTimelapses, setting: .timelapses, to: true) == [])
  }
}
