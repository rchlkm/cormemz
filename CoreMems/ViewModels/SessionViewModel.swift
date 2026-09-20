// CoreMems/ViewModels/SessionViewModel.swift
import Combine
import Foundation
import Photos
import UIKit

enum AppScreen: Equatable {
  case home
  case setup
  case review
  case pendingReview
  case completion
}

@MainActor
final class SessionViewModel: ObservableObject {

  // MARK: Published UI state
  @Published var screen: AppScreen = .home
  @Published var eligiblePhotoCount: Int = 0
  @Published var photos: [SessionPhoto] = []
  @Published var currentIndex: Int = 0
  @Published var history: [DecisionHistoryEntry] = []
  @Published var pendingNewAlbums: [AlbumOption] = []  // created-this-session, not yet flushed
  @Published var albumAssignmentError: String?
  @Published var isFlushingAlbums: Bool = false
  /// Every user album (names and counts only), loaded once per app launch and
  /// refreshed on foreground return and after album creation. `nil` until loaded.
  @Published var libraryAlbums: [AlbumOption]?
  /// Most recently used album IDs, newest first, capped at `recentAlbumIDsLimit`.
  /// Persisted, except session-local `.pendingNew` IDs.
  @Published var recentAlbumIDs: [String] = []
  @Published var albumAssignedCount: Int = 0
  @Published var deletedCount: Int = 0
  @Published var isDeleting: Bool = false
  @Published var deletionError: String?
  @Published var isConvertingLivePhoto: Bool = false
  @Published var livePhotoConversionError: String?
  @Published var metadataForSheet: PhotoMetadata?
  @Published var isLoadingMetadata: Bool = false

  /// Pinned Albums settings state. `pinnedAlbumIdentifiers` also drives the
  /// quick-access strip.
  @Published var allAlbumsForPinning: [AlbumOption] = []
  @Published var pinnedAlbumIdentifiers: Set<String> = []
  @Published var isLoadingAlbumsForPinning: Bool = false
  @Published var isCreatingPinnedAlbum: Bool = false
  @Published var pinnedAlbumCreationError: String?

  /// How many photos pass between check-in overlays during review.
  /// Persisted directly via `UserDefaults` — too small a setting to
  /// warrant its own file-backed service.
  @Published var checkInInterval: Int {
    didSet {
      UserDefaults.standard.set(checkInInterval, forKey: Self.checkInIntervalDefaultsKey)
    }
  }
  static let checkInIntervalRange = 5...100

  /// When true, sessions also include photos kept in earlier sessions.
  @Published var includesReviewedPhotos: Bool {
    didSet {
      UserDefaults.standard.set(includesReviewedPhotos, forKey: Self.includesReviewedDefaultsKey)
    }
  }
  @Published private(set) var reviewedPhotoCount: Int = 0
  private static let checkInIntervalDefaultsKey = "cm_checkInInterval"
  private static let includesReviewedDefaultsKey = "cm_includesReviewedPhotos"
  private static let recentAlbumIDsDefaultsKey = "cm_recentAlbumIDs"
  private static let defaultCheckInInterval = 12

  /// Describes how the active session's photos were selected, shown as
  /// a subtitle under the review progress line. `nil` for `.shuffle`.
  @Published var sessionLabel: String?

  // Dev-panel / edge-state toggles
  @Published var limitedAccess: Bool = false
  @Published var emptyLibrary: Bool = false
  @Published var lowInventoryOverride: Bool = false
  var maxAvailable: Int {
    lowInventoryOverride ? 4 : eligiblePhotoCount
  }

  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

  private let library: PhotoLibraryServicing
  private var pickedAssets: [String: PHAsset] = [:]  // photo.id -> PHAsset, for real deletion
  // @Published (despite being private) so toggling membership triggers
  // objectWillChange — the album picker's checkmarks read these
  // indirectly via `effectiveAlbums(for:)`.
  @Published private var initialAlbumMembership: [String: Set<String>] = [:]
  @Published private var stagedAdditions: [String: Set<AlbumRef>] = [:]
  @Published private var stagedRemovals: [String: Set<String>] = [:]
  private let persistence: SessionPersisting
  private let haptics: HapticsServicing
  private let metadataService: PhotoMetadataServicing
  private let statsStore: LifetimeStatsServicing
  private let pinnedAlbumsStore: PinnedAlbumsStoring
  private let reviewedPhotosStore: ReviewedPhotosStoring

  private static let cardDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
  }()

  var lifetimeStats: LifetimeSessionStats {
    statsStore.currentStats()
  }

  init(
    library: PhotoLibraryServicing = PhotoLibraryService(),
    persistence: SessionPersisting = SessionPersistence(),
    haptics: HapticsServicing = HapticsService(),
    metadataService: PhotoMetadataServicing = PhotoMetadataService(),
    statsStore: LifetimeStatsServicing = LifetimeStatsService(),
    pinnedAlbumsStore: PinnedAlbumsStoring = PinnedAlbumsStore(),
    reviewedPhotosStore: ReviewedPhotosStoring = ReviewedPhotosStore()
  ) {
    self.library = library
    self.persistence = persistence
    self.haptics = haptics
    self.metadataService = metadataService
    self.statsStore = statsStore
    self.pinnedAlbumsStore = pinnedAlbumsStore
    self.reviewedPhotosStore = reviewedPhotosStore
    let storedInterval =
      UserDefaults.standard.object(forKey: Self.checkInIntervalDefaultsKey) as? Int
    self.checkInInterval =
      storedInterval.map {
        min(max($0, Self.checkInIntervalRange.lowerBound), Self.checkInIntervalRange.upperBound)
      } ?? Self.defaultCheckInInterval
    self.includesReviewedPhotos = UserDefaults.standard.bool(
      forKey: Self.includesReviewedDefaultsKey)
    self.reviewedPhotoCount = reviewedPhotosStore.reviewedIdentifiers().count
    self.recentAlbumIDs = Self.loadPersistedRecentAlbumIDs()
    self.pinnedAlbumIdentifiers = pinnedAlbumsStore.pinnedAlbumIdentifiers()
    restoreIfInterrupted()
  }

  // MARK: Derived state

  var pendingItems: [SessionPhoto] { photos.filter { $0.decision == .pendingDelete } }
  var keptCount: Int { photos.filter { $0.decision == .keep }.count }
  var canUndo: Bool { !history.isEmpty }
  var isSessionShrunk: Bool { false }  // set true after startSession if capped

  /// Dev-panel override OR real `.limited` status — either should show
  /// the "you've shared a limited set of photos" banner.
  var isLimitedAccess: Bool { limitedAccess || authorizationStatus == .limited }

  /// Denied-access state.
  var isAccessDenied: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }

  /// MARK: Authorization

  /// Checks current status and, if the user has never been asked,
  /// triggers the system prompt. Call this before any flow that needs
  /// real photos — `startSession` does this automatically.
  @discardableResult
  func checkAuthorization() async -> PHAuthorizationStatus {
    var status = library.currentAuthorizationStatus()
    if status == .notDetermined {
      status = await library.requestAuthorization()
    }
    authorizationStatus = status
    return status
  }

  /// Re-reads status without prompting — call when the app returns to
  /// the foreground (e.g. after the user grants access in Settings or
  /// changes their Limited selection) so the UI updates on its own.
  func refreshAuthorizationStatus() {
    authorizationStatus = library.currentAuthorizationStatus()
    eligiblePhotoCount = library.totalEligibleAssetCount()
  }

  /// Single entry point for every "Manage access" affordance in the UI
  /// (Home's limited-access banner, the denied-access recovery screen).
  /// Routes to the right system surface based on current status.
  func manageAccess(presentingFrom viewController: UIViewController?) {
    switch authorizationStatus {
    case .limited:
      guard let viewController else { return }
      library.presentLimitedLibraryPicker(from: viewController)
    case .denied, .restricted:
      openSettings()
    case .notDetermined:
      Task { await checkAuthorization() }
    case .authorized:
      break
    @unknown default:
      break
    }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    Task { @MainActor in
      UIApplication.shared.open(url)
    }
  }

  // MARK: Session lifecycle

  /// Request/confirm authorization, fetch real assets via the method
  /// matching `mode`, or fall back to mock data when running in
  /// previews/simulator without a populated library. Every session is
  /// capped only by `maxAvailable` — there's no separate requested size.
  func startSession(mode: SelectionMode, startDate: Date?) async {
    let status = await checkAuthorization()
    guard status == .authorized || status == .limited else {
      // Denied/restricted — bounce back to Home, where
      // `isAccessDenied` will now show the recovery screen instead
      // of silently doing nothing.
      screen = .home
      return
    }

    let limit = max(maxAvailable, 0)
    let reviewed = includesReviewedPhotos ? [] : reviewedPhotosStore.reviewedIdentifiers()
    var assets = await fetchAssets(
      mode: mode, startDate: startDate, limit: limit, excluding: reviewed)
    // Everything in scope was already reviewed — show it again rather than an empty session.
    if assets.isEmpty, !reviewed.isEmpty, limit > 0, library.totalEligibleAssetCount() > 0 {
      assets = await fetchAssets(mode: mode, startDate: startDate, limit: limit, excluding: [])
    }

    if assets.isEmpty {
      // Preview/mock path — generates placeholder SessionPhoto data.
      photos = Self.mockPhotos(count: limit)
    } else {
      photos = assets.enumerated().map { idx, asset in
        let id = "\(asset.localIdentifier)-\(idx)"
        pickedAssets[id] = asset
        return SessionPhoto(
          id: id,
          assetIdentifier: asset.localIdentifier,
          previewURL: nil,
          isFavorite: asset.isFavorite,
          isLivePhoto: asset.mediaSubtypes.contains(.photoLive),
          dateLabel: asset.creationDate.map(Self.cardDateFormatter.string) ?? ""
        )
      }
    }

    switch mode {
    case .shuffle:
      sessionLabel = nil
    case .recent:
      sessionLabel = "Most recent first"
    case .date:
      sessionLabel = startDate.map { "Since \(Self.cardDateFormatter.string(from: $0))" }
    }

    currentIndex = 0
    history = []
    deletedCount = 0
    pendingNewAlbums = []
    albumAssignmentError = nil
    albumAssignedCount = 0
    initialAlbumMembership = [:]
    recentAlbumIDs = Self.loadPersistedRecentAlbumIDs()
    stagedAdditions = [:]
    stagedRemovals = [:]
    screen = .review
    prefetchNextPhoto()
    persistState()
  }

  private func fetchAssets(
    mode: SelectionMode, startDate: Date?, limit: Int, excluding: Set<String>
  ) async -> [PHAsset] {
    switch mode {
    case .shuffle:
      return await library.fetchRandomEligibleAssets(limit: limit, excluding: excluding)
    case .recent:
      return await library.fetchMostRecentEligibleAssets(limit: limit, excluding: excluding)
    case .date:
      let sinceDate = startDate ?? .distantPast
      return Array(
        await library.fetchEligibleAssets(since: sinceDate, excluding: excluding).prefix(limit))
    }
  }

  /// Jumps straight to Pending Review regardless of how many photos are
  /// left — the check-in overlay's "I'm done for now" and the review
  /// top bar's Done button both go through here.
  func finishEarly() {
    guard screen == .review else { return }
    screen = .pendingReview
    persistState()
  }

  // MARK: Keep / Delete / Undo

  /// Records a decision for the photo at `index`. If it's the
  /// currently-active photo, advances the review index — matches the
  /// swipe/tap gesture path. Restoring an earlier photo from the Tray
  /// goes through `restoreMany` instead, which never advances index.
  func decide(index: Int, decision: ReviewDecision) {
    guard photos.indices.contains(index) else { return }
    let previous = photos[index].decision
    let advanced = (index == currentIndex)
    history.append(
      DecisionHistoryEntry(
        photoIndex: index, previousDecision: previous, newDecision: decision,
        advancedIndex: advanced))
    photos[index].decision = decision

    switch decision {
    case .keep:
      haptics.keep()
    case .pendingDelete:
      haptics.markForDeletion()
    case .undecided:
      break
    }

    if advanced {
      currentIndex += 1
      prefetchNextPhoto()
    }

    if currentIndex >= photos.count && screen == .review {
      screen = .pendingReview
    }
    persistState()
  }

  /// Quick single-step Undo (swipe left / Undo button). Invariant #4:
  /// must never restore a photo submitted after final confirmation —
  /// enforced simply by the fact that `history` is cleared once
  /// deletion is confirmed (see `confirmDeletion`).
  func quickUndo() {
    guard let last = history.popLast() else { return }
    photos[last.photoIndex].decision = last.previousDecision
    if last.advancedIndex {
      currentIndex = last.photoIndex
      prefetchNextPhoto()
    }
    haptics.undo()
    persistState()
  }

  /// Toggles the favorite state for the given photo, updating both the
  /// in-session `SessionPhoto` and the underlying `PHAsset` (mock/preview
  /// photos, which have no backing `PHAsset`, update locally only).
  func toggleFavorite(photoID: String) {
    guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return }
    let newValue = !photos[index].isFavorite
    photos[index].isFavorite = newValue
    haptics.favorite()
    persistState()

    guard let asset = pickedAssets[photoID] else { return }
    Task { @MainActor in
      let result = await library.setFavorite(asset, isFavorite: newValue)
      if case .failure = result,
        let currentIndex = self.photos.firstIndex(where: { $0.id == photoID })
      {
        self.photos[currentIndex].isFavorite = !newValue
        self.persistState()
      }
    }
  }

  /// Converts a Live Photo to a plain still image in the user's library
  /// (new asset created, original deleted afterward — see
  /// `PhotoLibraryServicing.convertLivePhotoToStill`), then repoints this
  /// photo's in-session identity at the new asset.
  func convertLivePhotoToStill(photoID: String) {
    guard
      let index = photos.firstIndex(where: { $0.id == photoID }),
      photos[index].isLivePhoto,
      let asset = pickedAssets[photoID]
    else { return }

    isConvertingLivePhoto = true
    livePhotoConversionError = nil

    Task { @MainActor in
      let result = await library.convertLivePhotoToStill(asset)
      isConvertingLivePhoto = false

      switch result {
      case .success(let newIdentifier):
        guard let currentIndex = self.photos.firstIndex(where: { $0.id == photoID }) else { return }
        self.photos[currentIndex].assetIdentifier = newIdentifier
        self.photos[currentIndex].isLivePhoto = false
        if let newAsset = PHAsset.fetchAssets(
          withLocalIdentifiers: [newIdentifier], options: nil
        ).firstObject {
          self.pickedAssets[photoID] = newAsset
        }
        self.persistState()
      case .failure(let error):
        self.livePhotoConversionError = error.localizedDescription
      }
    }
  }

  /// Restores any number of pending-delete photos to Keep
  /// powers the Deletion Tray and the end-of-session multi-select grid.
  func restoreMany(ids: [String]) {
    guard !ids.isEmpty else { return }
    let idSet = Set(ids)
    var restoredAny = false
    for (i, photo) in photos.enumerated()
    where idSet.contains(photo.id) && photo.decision == .pendingDelete {
      history.append(
        DecisionHistoryEntry(
          photoIndex: i, previousDecision: .pendingDelete, newDecision: .keep, advancedIndex: false)
      )
      photos[i].decision = .keep
      restoredAny = true
    }
    if restoredAny {
      haptics.trayRestore()
    }
    persistState()
  }

  func toggleFavorite(id: String) {
    guard let i = photos.firstIndex(where: { $0.id == id }) else { return }
    photos[i].isFavorite.toggle()
  }

  // MARK: Album assignment

  /// Pinned plus recently used albums, resolved from `libraryAlbums` (empty until it loads).
  var quickAccessAlbums: [AlbumOption] {
    let ids = pinnedAlbumIdentifiers.union(recentAlbumIDs)
    return (libraryAlbums ?? []).filter { ids.contains($0.ref.identifier) }
  }

  /// Loads the albums `photoID` already belongs to, via a per-asset lookup. No-op once loaded.
  func loadAlbumMembership(for photoID: String) async {
    guard initialAlbumMembership[photoID] == nil,
      let assetID = photos.first(where: { $0.id == photoID })?.assetIdentifier
    else { return }
    initialAlbumMembership[photoID] = await library.fetchAlbumIdentifiers(
      containingAssetIdentifier: assetID)
  }

  /// Loads the library's album list once per app launch.
  func preloadLibraryAlbums() async {
    guard libraryAlbums == nil else { return }
    await refreshLibraryAlbums()
  }

  func refreshLibraryAlbums() async {
    libraryAlbums = await library.fetchAllUserAlbums()
  }

  /// Refreshes only once a list is loaded. Foreground album changes (e.g. iCloud
  /// sync) aren't observed; a `PHPhotoLibraryChangeObserver` would call this.
  func refreshLibraryAlbumsIfLoaded() async {
    guard libraryAlbums != nil else { return }
    await refreshLibraryAlbums()
  }

  // MARK: Pinned albums settings

  /// Every real album, for the Pinned Albums settings screen to browse
  /// and toggle — unlike the picker's default load, this always fetches
  /// the whole library, since it's a deliberate, infrequent settings
  /// visit rather than something that has to be instant every time a
  /// photo card opens.
  func loadAlbumsForPinning() {
    guard !isLoadingAlbumsForPinning else { return }
    isLoadingAlbumsForPinning = true
    pinnedAlbumIdentifiers = pinnedAlbumsStore.pinnedAlbumIdentifiers()
    Task { @MainActor in
      allAlbumsForPinning = await library.fetchAllUserAlbums()
      isLoadingAlbumsForPinning = false
    }
  }

  func togglePinnedAlbum(_ identifier: String) {
    if pinnedAlbumIdentifiers.contains(identifier) {
      pinnedAlbumIdentifiers.remove(identifier)
      pinnedAlbumsStore.unpin(identifier)
    } else {
      pinnedAlbumIdentifiers.insert(identifier)
      pinnedAlbumsStore.pin([identifier])
    }
  }

  /// Creates a real, empty Photos album from the Pinned Albums settings
  /// screen and immediately pins it — unlike the review picker's
  /// "New album" (which stays a `.pendingNew` placeholder until the
  /// session flushes it alongside a photo assignment), there's no photo
  /// to wait on here, so the album is created for real right away.
  func createAndPinAlbum(name: String) {
    guard !isCreatingPinnedAlbum else { return }
    isCreatingPinnedAlbum = true
    pinnedAlbumCreationError = nil
    Task { @MainActor in
      let result = await library.createAlbum(named: name)
      isCreatingPinnedAlbum = false
      switch result {
      case .success(let newAlbumID):
        pinnedAlbumsStore.pin([newAlbumID])
        pinnedAlbumIdentifiers.insert(newAlbumID)
        allAlbumsForPinning.append(
          AlbumOption(ref: .existing(localIdentifier: newAlbumID), name: name, assetCount: 0))
        allAlbumsForPinning.sort {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        await refreshLibraryAlbumsIfLoaded()
      case .failure(let error):
        pinnedAlbumCreationError = error.localizedDescription
      }
    }
  }

  /// The album picker's checkmark source — the real library's starting
  /// membership merged with this session's staged additions/removals.
  func effectiveAlbums(for photoID: String) -> Set<AlbumRef> {
    var result = Set((initialAlbumMembership[photoID] ?? []).map(AlbumRef.existing))
    if let removed = stagedRemovals[photoID] {
      result.subtract(removed.map(AlbumRef.existing))
    }
    if let added = stagedAdditions[photoID] {
      result.formUnion(added)
    }
    return result
  }

  /// Toggles `ref` for `photoID`. Toggling an album the photo already
  /// belonged to at session start (then back) collapses to a no-op
  /// against the real library instead of accumulating a log of taps.
  func toggleAlbumMembership(photoID: String, ref: AlbumRef) {
    let wasInitialMember =
      ref.kind == .existing && (initialAlbumMembership[photoID]?.contains(ref.identifier) ?? false)

    if effectiveAlbums(for: photoID).contains(ref) {
      // Also drops an add staged before membership loaded.
      stagedAdditions[photoID]?.remove(ref)
      if stagedAdditions[photoID]?.isEmpty == true {
        stagedAdditions.removeValue(forKey: photoID)
      }
      if wasInitialMember {
        stagedRemovals[photoID, default: []].insert(ref.identifier)
      }
    } else {
      // Turning on.
      if wasInitialMember {
        stagedRemovals[photoID]?.remove(ref.identifier)
        if stagedRemovals[photoID]?.isEmpty == true {
          stagedRemovals.removeValue(forKey: photoID)
        }
      } else {
        stagedAdditions[photoID, default: []].insert(ref)
      }
      recordRecentAlbum(ref.identifier)
    }
    refreshPendingAlbumCounts()
    persistState()
  }

  /// Only called when an album is turned on; turning one off leaves the list alone.
  private static let recentAlbumIDsLimit = 15
  private func recordRecentAlbum(_ identifier: String) {
    recentAlbumIDs.removeAll { $0 == identifier }
    recentAlbumIDs.insert(identifier, at: 0)
    if recentAlbumIDs.count > Self.recentAlbumIDsLimit {
      recentAlbumIDs.removeLast(recentAlbumIDs.count - Self.recentAlbumIDsLimit)
    }
    persistRecentAlbumIDs()
  }

  /// `.pendingNew` IDs are session-local temp UUIDs, so they're not persisted.
  private func persistRecentAlbumIDs() {
    let pendingIDs = Set(pendingNewAlbums.map(\.ref.identifier))
    let persistable = recentAlbumIDs.filter { !pendingIDs.contains($0) }
    UserDefaults.standard.set(persistable, forKey: Self.recentAlbumIDsDefaultsKey)
  }

  private static func loadPersistedRecentAlbumIDs() -> [String] {
    let stored = UserDefaults.standard.stringArray(forKey: recentAlbumIDsDefaultsKey) ?? []
    return Array(stored.prefix(recentAlbumIDsLimit))
  }

  /// Creates a not-yet-real album, staying pickable for other photos
  /// too (matching how the old shared folder list worked), optionally
  /// staging it onto one photo right away.
  func createPendingAlbum(name: String, assignToPhotoID: String?) {
    let ref = AlbumRef.pendingNew(tempID: UUID().uuidString, name: name)
    pendingNewAlbums.append(AlbumOption(ref: ref, name: name))
    if let photoID = assignToPhotoID {
      stagedAdditions[photoID, default: []].insert(ref)
    }
    refreshPendingAlbumCounts()
    persistState()
  }

  /// Keeps each pending album's displayed count in sync with how many
  /// photos are currently staged into it this session.
  private func refreshPendingAlbumCounts() {
    for i in pendingNewAlbums.indices {
      let ref = pendingNewAlbums[i].ref
      pendingNewAlbums[i].assetCount = stagedAdditions.values.filter { $0.contains(ref) }.count
    }
  }

  // MARK: Photo details

  /// Kicks off an async fetch for the pull-up details sheet — real
  /// assets go through PhotoKit/EXIF, mock/preview photos fall back to
  /// whatever's derivable from the SessionPhoto itself.
  func showMetadataSheet(for photoID: String) {
    isLoadingMetadata = true
    metadataForSheet = nil
    Task {
      if let asset = pickedAssets[photoID] {
        metadataForSheet = await metadataService.fetchMetadata(for: asset)
      } else if let photo = photos.first(where: { $0.id == photoID }) {
        metadataForSheet = PhotoMetadata.placeholder(for: photo)
      }
      isLoadingMetadata = false
    }
  }

  // MARK: Image prefetching

  private static let prefetchTargetSize = CGSize(width: 544, height: 748)

  /// Warms the image cache for the photo just ahead of `currentIndex`
  /// so swiping quickly never waits on a fetch. Safe to call whenever
  /// `currentIndex` changes; no-ops past the end of the session or for
  /// mock/preview photos that already have a `previewURL`.
  private func prefetchNextPhoto() {
    let nextIndex = currentIndex + 1
    guard photos.indices.contains(nextIndex) else { return }
    let next = photos[nextIndex]
    guard next.previewURL == nil else { return }
    Task {
      await PhotoImageLoader.shared.prefetchNext(
        identifier: next.assetIdentifier, targetSize: Self.prefetchTargetSize)
    }
  }

  // MARK: Confirm and Delete

  /// Submits the currently pending-delete assets and flushes staged
  /// album assignments — two independent `performChanges` transactions,
  /// run one after the other (not concurrently) because a photo can be
  /// staged for both in the same session: adding it to an album after
  /// it's already been deleted is unreliable, so the album flush goes
  /// first. Deletion always runs regardless of the album flush's
  /// outcome; only the screen transition to `.completion` waits on both
  /// succeeding.
  func confirmDeletion() async {
    let toDelete = pendingItems
    let keptNow = keptCount

    let albumsOK = await flushAlbumAssignments()

    if !toDelete.isEmpty {
      isDeleting = true
      deletionError = nil

      let assets = toDelete.compactMap { pickedAssets[$0.id] }
      let result = await library.deleteAssets(assets)

      isDeleting = false

      switch result {
      case .success:
        deletedCount = toDelete.count
        let deletedIDs = Set(toDelete.map(\.id))
        photos.removeAll { deletedIDs.contains($0.id) }
        history.removeAll()  // reversible window closes here
      case .failure(let error):
        // Failed deletion must be surfaced without falsely reporting
        // success, and must not corrupt unrelated session state
        // (Invariant #5) — we simply leave `photos`/`history` untouched.
        deletionError = error.localizedDescription
      }
    }

    guard albumsOK else { return }  // error + retry surfaced; stay put
    guard deletionError == nil else { return }  // existing behavior: leave user on screen

    haptics.sessionComplete()
    screen = .completion
    clearPersistedState()
    recordReviewedPhotos()
    recordSessionStats(kept: keptNow, deleted: deletedCount)
  }

  /// Flushes `stagedAdditions`/`stagedRemovals` in one transaction. On
  /// success, staged state is cleared; on failure it's left untouched so
  /// a retry is just calling this again with no other bookkeeping.
  @discardableResult
  private func flushAlbumAssignments() async -> Bool {
    guard !stagedAdditions.isEmpty || !stagedRemovals.isEmpty else { return true }
    isFlushingAlbums = true
    albumAssignmentError = nil

    let result = await library.commitAlbumAssignments(
      additions: stagedAdditions, removals: stagedRemovals, assets: pickedAssets)

    isFlushingAlbums = false

    switch result {
    case .success(let createdAlbumIDs):
      pinnedAlbumsStore.pin(createdAlbumIDs)
      if !createdAlbumIDs.isEmpty {
        Task { await refreshLibraryAlbumsIfLoaded() }
      }
      albumAssignedCount = stagedAdditions.keys.count
      stagedAdditions = [:]
      stagedRemovals = [:]
      pendingNewAlbums = []
      persistState()
      return true
    case .failure(let error):
      albumAssignmentError = error.localizedDescription
      return false
    }
  }

  /// Retry entry point for the album-assignment error banner — only
  /// re-attempts the album flush; deletion (if any) already resolved in
  /// the `confirmDeletion` call that produced the error.
  func retryAlbumAssignments() {
    Task {
      guard await flushAlbumAssignments() else { return }
      guard deletionError == nil else { return }
      haptics.sessionComplete()
      screen = .completion
      clearPersistedState()
      recordReviewedPhotos()
      recordSessionStats(kept: keptCount, deleted: deletedCount)
    }
  }

  /// Folds a finished session's decisions into the persisted lifetime
  /// stats via `statsStore`, which also logs a snapshot for debugging.
  private func recordSessionStats(kept: Int, deleted: Int) {
    statsStore.recordSession(kept: kept, deleted: deleted)
  }

  /// Remembers the session's kept photos so later sessions skip them.
  /// Photos marked for deletion aren't recorded: they're either gone
  /// after confirmation or, if the session is abandoned, still unreviewed.
  private func recordReviewedPhotos() {
    let keptIdentifiers = photos
      .filter { $0.decision == .keep && pickedAssets[$0.id] != nil }
      .map(\.assetIdentifier)
    reviewedPhotosStore.markReviewed(Set(keptIdentifiers))
    reviewedPhotoCount = reviewedPhotosStore.reviewedIdentifiers().count
  }

  /// Makes every photo eligible for review again.
  func resetReviewedPhotos() {
    reviewedPhotosStore.clear()
    reviewedPhotoCount = 0
  }

  func exitToHome() {
    recordReviewedPhotos()
    clearPersistedState()
    screen = .home
  }

  func resetForAnotherSession() {
    screen = .setup
  }

  // MARK: Persistence

  /// Called on every decision so a backgrounded/killed app can resume
  /// exactly where the user left off
  private func persistState() {
    guard screen == .review || screen == .pendingReview else { return }
    let snapshot = PersistedSessionSnapshot(
      photoIDs: photos.map(\.id),
      decisions: photos.map(\.decision.rawValue),
      assetIdentifiers: photos.map(\.assetIdentifier),
      currentIndex: currentIndex,
      historyPhotoIndices: history.map(\.photoIndex),
      historyPrevious: history.map(\.previousDecision.rawValue),
      historyNew: history.map(\.newDecision.rawValue),
      historyAdvanced: history.map(\.advancedIndex),
      albumAdditions: stagedAdditions,
      albumRemovals: stagedRemovals,
      pendingNewAlbumRefs: pendingNewAlbums.map(\.ref)
    )
    persistence.save(snapshot)
  }

  private func clearPersistedState() {
    persistence.clear()
  }

  private func restoreIfInterrupted() {
    guard let snapshot = persistence.load() else { return }
    // Rehydrate photos with placeholder preview data — production
    // code would re-resolve PHAssets by localIdentifier here.
    photos = zip(snapshot.photoIDs, zip(snapshot.decisions, snapshot.assetIdentifiers)).map {
      id, rest in
      let (decisionRaw, assetID) = rest
      var p = SessionPhoto(id: id, assetIdentifier: assetID, previewURL: nil)
      p.decision = ReviewDecision(rawValue: decisionRaw) ?? .undecided
      return p
    }
    // Re-resolve real PHAssets so a resumed session's deletion and
    // album flush have something to act on — without this, both would
    // silently no-op against an empty `pickedAssets`.
    let resolvedAssets = PHAsset.fetchAssets(
      withLocalIdentifiers: snapshot.assetIdentifiers, options: nil)
    var assetsByID: [String: PHAsset] = [:]
    resolvedAssets.enumerateObjects { asset, _, _ in assetsByID[asset.localIdentifier] = asset }
    for photo in photos {
      if let asset = assetsByID[photo.assetIdentifier] {
        pickedAssets[photo.id] = asset
      }
    }
    stagedAdditions = snapshot.albumAdditions
    stagedRemovals = snapshot.albumRemovals
    pendingNewAlbums = snapshot.pendingNewAlbumRefs.map {
      AlbumOption(ref: $0, name: $0.name ?? "")
    }
    refreshPendingAlbumCounts()
    currentIndex = snapshot.currentIndex
    history = zip(
      snapshot.historyPhotoIndices,
      zip(snapshot.historyPrevious, zip(snapshot.historyNew, snapshot.historyAdvanced))
    ).map { idx, rest in
      let (prevRaw, restInner) = rest
      let (newRaw, advanced) = restInner
      return DecisionHistoryEntry(
        photoIndex: idx,
        previousDecision: ReviewDecision(rawValue: prevRaw) ?? .undecided,
        newDecision: ReviewDecision(rawValue: newRaw) ?? .undecided,
        advancedIndex: advanced
      )
    }
    screen = currentIndex >= photos.count ? .pendingReview : .review
    prefetchNextPhoto()
  }

  // MARK: Mock data for previews / empty-library demos

  static func mockPhotos(count: Int) -> [SessionPhoto] {
    (0..<count).map { i in
      let date = Calendar.current.date(byAdding: .day, value: -i * 11, to: Date()) ?? Date()
      return SessionPhoto(
        id: "mock-\(i)",
        assetIdentifier: "mock-asset-\(i)",
        previewURL: URL(string: "https://picsum.photos/seed/coremems-\(i)/420/580"),
        isFavorite: i % 4 == 1,
        isLivePhoto: i % 5 == 2,
        dateLabel: cardDateFormatter.string(from: date)
      )
    }
  }
}

#if DEBUG
  extension SessionViewModel {
    /// Configures a `SessionViewModel` for SwiftUI Previews. Every
    /// parameter maps directly onto published state. `maxAvailable` and
    /// `keptCount` are computed properties and can't be set directly —
    /// drive them by passing `eligiblePhotoCount` and a `photos` array
    /// (e.g. via `mockPhotos(count:)`) instead.
    static func mock(
      screen: AppScreen = .home,
      isAccessDenied: Bool = false,
      eligiblePhotoCount: Int = 100,
      photos: [SessionPhoto] = [],
      currentIndex: Int = 0,
      deletedCount: Int = 0
    ) -> SessionViewModel {
      let vm = SessionViewModel()
      vm.screen = screen
      vm.authorizationStatus = isAccessDenied ? .denied : .authorized
      vm.eligiblePhotoCount = eligiblePhotoCount
      vm.photos = photos
      vm.currentIndex = currentIndex
      vm.deletedCount = deletedCount
      return vm
    }
  }
#endif
