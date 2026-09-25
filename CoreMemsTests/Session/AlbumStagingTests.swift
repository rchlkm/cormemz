// CoreMemsTests/Session/AlbumStagingTests.swift
import Testing

@testable import CoreMems

@Suite("Album staging")
struct AlbumStagingTests {
  private let trips = AlbumRef.existing(localIdentifier: "trips")
  private let family = AlbumRef.existing(localIdentifier: "family")

  @Test func togglingANewAlbumOnStagesAnAddition() {
    var staging = AlbumStaging()

    let isMember = staging.toggle(photoID: "p1", ref: trips)

    #expect(isMember)
    #expect(staging.additions["p1"] == [trips])
    #expect(staging.effectiveAlbums(for: "p1") == [trips])
  }

  @Test func togglingTheSameAlbumOffAgainStagesNothing() {
    var staging = AlbumStaging()
    staging.toggle(photoID: "p1", ref: trips)

    let isMember = staging.toggle(photoID: "p1", ref: trips)

    #expect(!isMember)
    #expect(staging.additions.isEmpty)
    #expect(staging.removals.isEmpty)
  }

  @Test func removingAnInitialAlbumStagesARemovalAndReAddingCollapsesIt() {
    var staging = AlbumStaging()
    staging.setInitialMembership(["trips"], for: "p1")
    #expect(staging.effectiveAlbums(for: "p1") == [trips])

    staging.toggle(photoID: "p1", ref: trips)
    #expect(staging.removals["p1"] == ["trips"])
    #expect(staging.effectiveAlbums(for: "p1").isEmpty)

    staging.toggle(photoID: "p1", ref: trips)
    #expect(staging.removals.isEmpty)
    #expect(staging.additions.isEmpty)
    #expect(staging.effectiveAlbums(for: "p1") == [trips])
  }

  @Test func pendingAlbumCountsFollowTheStagedPhotos() {
    var staging = AlbumStaging()
    staging.createPendingAlbum(name: "Hikes", assignTo: "p1")
    let pending = staging.pendingNewAlbums[0].ref
    #expect(staging.pendingNewAlbums[0].assetCount == 1)

    staging.toggle(photoID: "p2", ref: pending)
    #expect(staging.pendingNewAlbums[0].assetCount == 2)

    staging.toggle(photoID: "p1", ref: pending)
    #expect(staging.pendingNewAlbums[0].assetCount == 1)
  }

  @Test func changesLeaveOutPhotosBeingDeleted() {
    var staging = AlbumStaging()
    staging.setInitialMembership(["family"], for: "p2")
    staging.toggle(photoID: "p1", ref: trips)
    staging.toggle(photoID: "p2", ref: family)

    let changes = staging.changes(excludingPhotoIDs: ["p2"])

    #expect(changes.additions == ["p1": [trips]])
    #expect(changes.removals.isEmpty)
  }

  @Test func clearingStagedChangesKeepsTheInitialMembership() {
    var staging = AlbumStaging()
    staging.setInitialMembership(["trips"], for: "p1")
    staging.createPendingAlbum(name: "Hikes", assignTo: "p1")

    staging.clearStaged()

    #expect(staging.additions.isEmpty)
    #expect(staging.pendingNewAlbums.isEmpty)
    #expect(staging.hasInitialMembership(for: "p1"))
  }
}
