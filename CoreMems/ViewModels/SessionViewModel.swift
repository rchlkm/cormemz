// CoreMems/ViewModels/SessionViewModel.swift
import Combine
import Foundation
import Photos

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
  @Published var isStartingSession: Bool = false
  /// Every user album (names and counts only), loaded once per app launch and
  /// refreshed on foreground return and after album creation. `nil` until loaded.
  @Published var libraryAlbums: [AlbumOption]? {
    didSet {
      libraryAlbumsByID = Dictionary(
        (libraryAlbums ?? []).map { ($0.ref.identifier, $0) },
        uniquingKeysWith: { first, _ in first })
    }
  }
  private var libraryAlbumsByID: [String: AlbumOption] = [:]
  @Published var albumAssignedCount: Int = 0
  @Published var deletedCount: Int = 0
  @Published var isDeleting: Bool = false
  @Published var deletionError: String?
  @Published var convertedLivePhotoCount: Int = 0
  
  /// The decision being shown before it's recorded; decisions and undo are ignored meanwhile.
  @Published private(set) var markingDecision: ReviewDecision?
  @Published var metadataForSheet: PhotoMetadata?
  @Published var isLoadingMetadata: Bool = false

  @Published private var settings = SessionSettings()
  var checkInInterval: Int {
    get { settings.checkInInterval }
    set { settings.checkInInterval = newValue }
  }
  var includesReviewedPhotos: Bool {
    get { settings.includesReviewedPhotos }
    set { settings.includesReviewedPhotos = newValue }
  }
  @Published private(set) var reviewedPhotoCount: Int = 0

  /// Describes how the active session's photos were selected, shown as
  /// a subtitle under the review progress line. `nil` for `.shuffle`.
  @Published var sessionLabel: String?

  /// The library neighbors being browsed around the session photo; `nil` when not peeking.
  @Published var peek: PeekState?

  // Dev-panel / edge-state toggles
  @Published var limitedAccess: Bool = false
  @Published var emptyLibrary: Bool = false
  @Published var lowInventoryOverride: Bool = false
  var maxAvailable: Int {
    lowInventoryOverride ? 4 : eligiblePhotoCount
  }

  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

  let library: PhotoLibraryServicing
  private let commitService: SessionCommitService
  let pinnedAlbums: PinnedAlbumsViewModel
  private var pinnedAlbumsObservation: AnyCancellable?
  var pickedAssets: [String: PHAsset] = [:]  // photo.id -> PHAsset, for real deletion
  @Published var peekedPhotos: [String: SessionPhoto] = [:]  // asset id -> neighbor not in the deck
  private var deletedBytes: Int64 = 0
  /// Source of the photos not yet loaded into `photos`; `nil` once it runs dry.
  private var assetSource: (any AssetBatching)?
  private var sessionBatchSize = SessionSettings.defaultCheckInInterval
  private var isLoadingBatch = false
  /// Batches of unreviewed photos kept loaded ahead of the current card.
  private static let lookaheadBatches = 2
  /// How long each decision stays on screen before it's recorded; unlisted ones record at once.
  private static let decisionHolds: [ReviewDecision: Duration] = [
    .convertToStill: .milliseconds(450)
  ]
  @Published private var albumStaging = AlbumStaging()
  @Published private var recentAlbums = RecentAlbums()
  private let persistence: SessionPersisting
  private let haptics: HapticsServicing
  private let metadataService: PhotoMetadataServicing
  private let statsStore: LifetimeStatsServicing
  private let reviewedPhotosStore: ReviewedPhotosStoring

  static let cardDateFormatter: DateFormatter = {
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
    commitService = SessionCommitService(library: library)
    pinnedAlbums = PinnedAlbumsViewModel(library: library, store: pinnedAlbumsStore)
    self.reviewedPhotosStore = reviewedPhotosStore
    self.reviewedPhotoCount = reviewedPhotosStore.reviewedIdentifiers().count
    pinnedAlbums.onAlbumCreated = { [weak self] in await self?.refreshLibraryAlbumsIfLoaded() }
    // Only the state `quickAccessAlbums` reads re-renders this object's observers.
    pinnedAlbumsObservation = Publishers.Merge(
      pinnedAlbums.$identifiers.removeDuplicates().dropFirst().map { _ in },
      pinnedAlbums.$sort.removeDuplicates().dropFirst().map { _ in }
    ).sink { [weak self] in self?.objectWillChange.send() }
    restoreIfInterrupted()
  }

  // MARK: Derived state

  var pendingItems: [SessionPhoto] { photos.filter { $0.decision == .pendingDelete } }
  var pendingConversions: [SessionPhoto] { photos.filter { $0.decision == .convertToStill } }
  /// Deletions and conversions together, in the order they were reviewed.
  var markedPhotos: [SessionPhoto] { photos.filter { $0.decision.isMarked } }
  var keptCount: Int { photos.filter { $0.decision.isKept }.count }
  var canUndo: Bool { !history.isEmpty && !isPeeking }
  var currentPhoto: SessionPhoto? { photos.indices.contains(currentIndex) ? photos[currentIndex] : nil }

  // MARK: Session lifecycle

  /// Request/confirm authorization, then load the first batches of real
  /// assets in `mode`'s order, or fall back to mock data when running in
  /// previews/simulator without a populated library. A batch is
  /// `checkInInterval` photos; later batches load as the user reviews.
  func startSession(mode: SelectionMode, startDate: Date?) async {
    guard !isStartingSession else { return }
    isStartingSession = true
    defer { isStartingSession = false }

    let status = await checkAuthorization()
    guard status == .authorized || status == .limited else {
      // Denied/restricted — bounce back to Home, where
      // `isAccessDenied` will now show the recovery screen instead
      // of silently doing nothing.
      screen = .home
      return
    }

    let limit = max(maxAvailable, 0)
    let batchSize = checkInInterval
    let initialCount = Self.lookaheadBatches * batchSize
    let reviewed = includesReviewedPhotos ? [] : reviewedPhotosStore.reviewedIdentifiers()
    var source = await library.makeAssetSource(
      mode: mode, startDate: startDate, excluding: reviewed)
    var assets = await source.nextBatch(count: initialCount)
    // Everything in scope was already reviewed — show it again rather than an empty session.
    if assets.isEmpty, !reviewed.isEmpty, limit > 0, library.totalEligibleAssetCount() > 0 {
      source = await library.makeAssetSource(mode: mode, startDate: startDate, excluding: [])
      assets = await source.nextBatch(count: initialCount)
    }

    if assets.isEmpty {
      // Preview/mock path — generates placeholder SessionPhoto data.
      photos = Self.mockPhotos(count: limit)
      assetSource = nil
    } else {
      photos = sessionPhotos(from: assets, startingAt: 0)
      assetSource = assets.count < initialCount ? nil : source
    }
    sessionBatchSize = batchSize
    isLoadingBatch = false

    switch mode {
    case .shuffle:
      sessionLabel = nil
    case .recent:
      sessionLabel = "Most recent first"
    case .date:
      sessionLabel = startDate.map { "From \(Self.cardDateFormatter.string(from: $0))" }
    }

    currentIndex = 0
    history = []
    deletedCount = 0
    deletedBytes = 0
    convertedLivePhotoCount = 0
    albumAssignedCount = 0
    albumStaging = AlbumStaging()
    recentAlbums = RecentAlbums()
    screen = .review
    prefetchNextPhoto()
    persistState()
  }

  func sessionPhotos(from assets: [PHAsset], startingAt offset: Int) -> [SessionPhoto] {
    assets.enumerated().map { idx, asset in
      let id = "\(asset.localIdentifier)-\(offset + idx)"
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

  /// Loads another batch whenever fewer than `lookaheadBatches` batches of
  /// photos remain ahead of the current card.
  private func loadMoreIfNeeded() {
    let batchSize = sessionBatchSize
    guard let source = assetSource, !isLoadingBatch,
      photos.count - currentIndex < Self.lookaheadBatches * batchSize
    else { return }
    isLoadingBatch = true
    Task {
      let assets = await source.nextBatch(count: batchSize)
      guard source === assetSource else { return }
      isLoadingBatch = false
      let decided = Set(photos.map(\.assetIdentifier))
      let fresh = assets.filter { !decided.contains($0.localIdentifier) }
      photos.append(contentsOf: sessionPhotos(from: fresh, startingAt: photos.count))
      if assets.count < batchSize { assetSource = nil }
      prefetchNextPhoto()
      showPendingReviewIfDeckEmpty()
      loadMoreIfNeeded()
      persistState()
    }
  }

  /// An empty deck only means the session is over once no more photos can arrive.
  private func showPendingReviewIfDeckEmpty() {
    guard currentIndex >= photos.count, assetSource == nil, screen == .review else { return }
    endPeek()
    screen = .pendingReview
  }

  /// Jumps straight to Pending Review regardless of how many photos are
  /// left — the check-in overlay's "I'm done for now" and the review
  /// top bar's Done button both go through here.
  func finishEarly() {
    guard screen == .review else { return }
    endPeek()
    screen = .pendingReview
    persistState()
  }

  // MARK: Keep / Delete / Undo

  /// Records a decision for the photo at `index`, first showing it for its hold in
  /// `decisionHolds`, if any. Recording advances the review index if it's the active
  /// photo — matches the swipe/tap gesture path. Restoring an earlier photo from the
  /// Tray goes through `restoreMany` instead, which never advances index.
  /// Returns the task that finishes once recorded, or `nil` if the decision was ignored.
  @discardableResult
  func decide(index: Int, decision: ReviewDecision) -> Task<Void, Never>? {
    guard markingDecision == nil, photos.indices.contains(index) else { return nil }
    guard decision != .convertToStill || photos[index].isLivePhoto else { return nil }

    switch decision {
    case .keep:
      haptics.keep()
    case .pendingDelete:
      haptics.markForDeletion()
    case .convertToStill:
      haptics.convertToStill()
    case .undecided:
      break
    }

    guard let hold = Self.decisionHolds[decision] else {
      record(index: index, decision: decision)
      return Task {}
    }
    markingDecision = decision
    return Task {
      try? await Task.sleep(for: hold)
      markingDecision = nil
      record(index: index, decision: decision)
    }
  }

  /// Decides on the photo with this id — the active photo, a photo ahead in the deck, or a
  /// peeked neighbor. Anything but the active photo joins the reviewed part of the deck
  /// without moving the active photo. Peeked neighbors can't be kept.
  @discardableResult
  func decide(photoID: String, decision: ReviewDecision) -> Task<Void, Never>? {
    guard markingDecision == nil,
      decision != .keep || !isPeekedNeighbor(photoID), let photo = photo(withID: photoID),
      decision != .convertToStill || photo.isLivePhoto,
      let index = adoptIntoReviewed(photoID)
    else { return nil }
    return decide(index: index, decision: decision)
  }

  /// Moves a photo that isn't the active card — an unloaded neighbor or one ahead in the
  /// deck — in front of it, counting it as reviewed. Returns the photo's deck index.
  private func adoptIntoReviewed(_ photoID: String) -> Int? {
    let adopted: SessionPhoto
    if let index = photos.firstIndex(where: { $0.id == photoID }) {
      guard index > currentIndex else { return index }
      adopted = photos.remove(at: index)
    } else if let entry = peekedPhotos.first(where: { $0.value.id == photoID }) {
      peekedPhotos[entry.key] = nil
      adopted = entry.value
    } else {
      return nil
    }
    photos.insert(adopted, at: currentIndex)
    currentIndex += 1
    return currentIndex - 1
  }

  /// A deck photo or a peeked neighbor.
  func photo(withID photoID: String) -> SessionPhoto? {
    photos.first { $0.id == photoID } ?? peekedPhotos.values.first { $0.id == photoID }
  }

  private func record(index: Int, decision: ReviewDecision) {
    guard photos.indices.contains(index) else { return }
    let previous = photos[index].decision
    let advanced = (index == currentIndex)
    history.append(
      DecisionHistoryEntry(
        photoIndex: index, previousDecision: previous, newDecision: decision,
        advancedIndex: advanced))
    photos[index].decision = decision

    if advanced {
      currentIndex += 1
      prefetchNextPhoto()
      loadMoreIfNeeded()
    }

    showPendingReviewIfDeckEmpty()
    persistState()
  }

  /// Quick single-step Undo (swipe left / Undo button). 
  /// must never restore a photo submitted after final confirmation —
  /// enforced simply by the fact that `history` is cleared once
  /// deletion is confirmed (see `confirmDeletion`).
  ///
  /// Stepping back onto a conversion leaves it marked, so the still can be
  /// filed into an album or the decision changed on purpose.
  func quickUndo() {
    guard markingDecision == nil, let last = history.popLast() else { return }
    if !(last.advancedIndex && last.newDecision == .convertToStill) {
      photos[last.photoIndex].decision = last.previousDecision
    }
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
    guard let photo = photo(withID: photoID) else { return }
    let newValue = !photo.isFavorite
    setFavoriteLocally(photoID, newValue)
    haptics.favorite()
    persistState()

    guard let asset = pickedAssets[photoID] else { return }
    Task { @MainActor in
      let result = await library.setFavorite(asset, isFavorite: newValue)
      if case .failure = result {
        self.setFavoriteLocally(photoID, !newValue)
        self.persistState()
      }
    }
  }

  /// Favoriting doesn't review a photo, so a peeked neighbor stays where it is.
  private func setFavoriteLocally(_ photoID: String, _ isFavorite: Bool) {
    if let index = photos.firstIndex(where: { $0.id == photoID }) {
      photos[index].isFavorite = isFavorite
    } else if let key = peekedPhotos.first(where: { $0.value.id == photoID })?.key {
      peekedPhotos[key]?.isFavorite = isFavorite
    }
  }

  /// Repoints each converted photo at its still copy as a plain keep and records the
  /// space freed by dropping the video.
  private func applyConversions(_ conversions: [SessionPhoto], from commit: SessionCommitResult) {
    for photo in conversions {
      guard let still = commit.stills[photo.id],
        let index = photos.firstIndex(where: { $0.id == photo.id })
      else { continue }
      photos[index].assetIdentifier = still.identifier
      photos[index].isLivePhoto = false
      photos[index].decision = .keep
      if let asset = still.asset { pickedAssets[photo.id] = asset }
      statsStore.recordLivePhotoConversion(bytesSaved: still.bytesSaved)
      convertedLivePhotoCount += 1
    }
  }

  /// Restores any number of marked photos to Keep; powers the Marked Photos
  /// tray and the end-of-session grids.
  func restoreMany(ids: [String]) {
    guard !ids.isEmpty else { return }
    let idSet = Set(ids)
    var restoredAny = false
    for (i, photo) in photos.enumerated()
    where idSet.contains(photo.id) && photo.decision.isMarked {
      history.append(
        DecisionHistoryEntry(
          photoIndex: i, previousDecision: photo.decision, newDecision: .keep, advancedIndex: false)
      )
      photos[i].decision = .keep
      restoredAny = true
    }
    if restoredAny {
      haptics.trayRestore()
    }
    persistState()
  }

  // MARK: Album assignment

  /// Albums created this session, not yet flushed.
  var pendingNewAlbums: [AlbumOption] { albumStaging.pendingNewAlbums }

  /// Most recently used album IDs, newest first.
  var recentAlbumIDs: [String] { recentAlbums.ids }

  /// Pinned album IDs in the chosen sort order.
  var orderedPinnedAlbumIDs: [String] { pinnedAlbums.orderedIdentifiers(recents: recentAlbumIDs) }

  /// Pinned albums in their sort order, then unpinned recents newest first, resolved from
  /// `libraryAlbums` (empty until it loads).
  var quickAccessAlbums: [AlbumOption] {
    let pinned = orderedPinnedAlbumIDs
    let ids = pinned + recentAlbumIDs.filter { !pinned.contains($0) }
    return ids.compactMap { libraryAlbumsByID[$0] }
  }

  /// Loads the albums `photoID` already belongs to, via a per-asset lookup. No-op once loaded.
  func loadAlbumMembership(for photoID: String) async {
    guard !albumStaging.hasInitialMembership(for: photoID),
      let assetID = photo(withID: photoID)?.assetIdentifier
    else { return }
    albumStaging.setInitialMembership(
      await library.fetchAlbumIdentifiers(containingAssetIdentifier: assetID), for: photoID)
  }

  /// Loads the library's album list once per app launch.
  func preloadLibraryAlbums() async {
    guard libraryAlbums == nil else { return }
    await refreshLibraryAlbums()
  }

  func refreshLibraryAlbums() async {
    libraryAlbums = await library.fetchAllUserAlbums()
  }

  /// Re-reads access, the photo count and the album list.
  func refreshLibrary() async {
    refreshAuthorizationStatus()
    await refreshLibraryAlbums()
  }

  /// Refreshes only once a list is loaded. Foreground album changes (e.g. iCloud
  /// sync) aren't observed; a `PHPhotoLibraryChangeObserver` would call this.
  func refreshLibraryAlbumsIfLoaded() async {
    guard libraryAlbums != nil else { return }
    await refreshLibraryAlbums()
  }

  /// The album picker's checkmark source — the real library's starting
  /// membership merged with this session's staged additions/removals.
  func effectiveAlbums(for photoID: String) -> Set<AlbumRef> {
    albumStaging.effectiveAlbums(for: photoID)
  }

  /// Toggles `ref` for `photoID`, recording it as recent when turned on.
  func toggleAlbumMembership(photoID: String, ref: AlbumRef) {
    haptics.albumToggle()
    if albumStaging.toggle(photoID: photoID, ref: ref) {
      recentAlbums.record(ref.identifier)
      recentAlbums.persist(excluding: Set(pendingNewAlbums.map(\.ref.identifier)))
    }
    persistState()
  }

  /// Creates a not-yet-real album, optionally staging it onto one photo right away.
  func createPendingAlbum(name: String, assignToPhotoID: String?) {
    albumStaging.createPendingAlbum(name: name, assignTo: assignToPhotoID)
    persistState()
  }

  /// A random eligible photo's date, for starting a `.date` session without picking one.
  func randomAssetDate() async -> Date? { await library.randomAssetDate() }

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

  /// Applies everything staged this session as one library transaction: still copies
  /// of converted Live Photos, album changes, and deletions. All of it happens or none
  /// of it does, behind a single system prompt.
  func confirmDeletion() async {
    let toDelete = pendingItems
    let conversions = pendingConversions.filter { pickedAssets[$0.id] != nil }
    let keptNow = keptCount

    // Album changes on a photo that's being deleted are moot.
    let deletedIDs = Set(toDelete.map(\.id))
    let (additions, removals) = albumStaging.changes(excludingPhotoIDs: deletedIDs)
    let changes = SessionLibraryChanges(
      deletions: toDelete.compactMap { pickedAssets[$0.id] },
      conversions: conversions.reduce(into: [String: PHAsset]()) { $0[$1.id] = pickedAssets[$1.id] },
      albumAdditions: additions, albumRemovals: removals, albumAssets: pickedAssets)

    if !changes.isEmpty {
      isDeleting = true
      deletionError = nil

      let result = await commitService.commit(changes)
      isDeleting = false

      switch result {
      case .success(let commit):
        applyConversions(conversions, from: commit)
        let createdAlbumIDs = commit.outcome.createdAlbumIDs
        pinnedAlbums.pin(createdAlbumIDs.sorted())
        if !createdAlbumIDs.isEmpty {
          Task { await refreshLibraryAlbumsIfLoaded() }
        }
        albumAssignedCount = additions.count
        albumStaging.clearStaged()
        deletedCount = toDelete.count
        deletedBytes = commit.bytesDeleted
        photos.removeAll { deletedIDs.contains($0.id) }
        history.removeAll()  // reversible window closes here

        guard conversions.allSatisfy({ commit.stills[$0.id] != nil }) else {
          deletionError = PhotoLibraryError.creationFailed.localizedDescription
          persistState()
          return
        }
      case .failure(let error):
        // Nothing was applied, so the session is left as it was. Declining the
        // system prompt isn't an error, but the session stays open.
        if (error as? PHPhotosError)?.code != .userCancelled {
          deletionError = error.localizedDescription
        }
        return
      }
    }

    haptics.sessionComplete()
    screen = .completion
    persistence.clear()
    eligiblePhotoCount = library.totalEligibleAssetCount()
    recordReviewedPhotos()
    statsStore.recordSession(kept: keptNow, deleted: deletedCount, bytesDeleted: deletedBytes)
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

  /// Zeroes the lifetime stats; the next recorded activity restarts the tracking date.
  func clearLifetimeStats() {
    statsStore.clear()
    objectWillChange.send()
  }

  /// Makes every photo eligible for review again.
  func resetReviewedPhotos() {
    reviewedPhotosStore.clear()
    reviewedPhotoCount = 0
  }

  func exitToHome() {
    endPeek()
    recordReviewedPhotos()
    persistence.clear()
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
    persistence.save(
      PersistedSessionSnapshot(
        photos: photos, currentIndex: currentIndex, history: history, albumStaging: albumStaging))
  }

  private func restoreIfInterrupted() {
    guard let snapshot = persistence.load() else { return }
    photos = snapshot.restoredPhotos
    // Resolves the real assets, so deleting and filing into albums work on a resumed session.
    let resolvedAssets = PHAsset.fetchAssets(
      withLocalIdentifiers: snapshot.assetIdentifiers, options: nil)
    var assetsByID: [String: PHAsset] = [:]
    resolvedAssets.enumerateObjects { asset, _, _ in assetsByID[asset.localIdentifier] = asset }
    for photo in photos {
      if let asset = assetsByID[photo.assetIdentifier] {
        pickedAssets[photo.id] = asset
      }
    }
    albumStaging = snapshot.restoredAlbumStaging
    currentIndex = snapshot.currentIndex
    history = snapshot.restoredHistory
    screen = currentIndex >= photos.count ? .pendingReview : .review
    prefetchNextPhoto()
  }
}
