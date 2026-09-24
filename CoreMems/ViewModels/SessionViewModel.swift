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
  /// Most recently used album IDs, newest first, capped at `recentAlbumIDsLimit`.
  /// Persisted, except session-local `.pendingNew` IDs.
  @Published var recentAlbumIDs: [String] = []
  @Published var albumAssignedCount: Int = 0
  @Published var deletedCount: Int = 0
  @Published var isDeleting: Bool = false
  @Published var deletionError: String?
  @Published var convertedLivePhotoCount: Int = 0
  
  /// The decision being shown before it's recorded; decisions and undo are ignored meanwhile.
  @Published private(set) var markingDecision: ReviewDecision?
  @Published var metadataForSheet: PhotoMetadata?
  @Published var isLoadingMetadata: Bool = false

  /// How many photos pass between check-in overlays during review.
  /// Persisted directly via `UserDefaults` — too small a setting to
  /// warrant its own file-backed service.
  @Published var checkInInterval: Int {
    didSet {
      UserDefaults.standard.set(checkInInterval, forKey: Self.checkInIntervalDefaultsKey)
    }
  }
  static let checkInIntervalRange = 5...50

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

  /// The library neighbors being browsed around the session photo; `nil` when not peeking.
  @Published private(set) var peek: PeekState?
  var isPeeking: Bool { peek != nil }

  /// A peeked photo other than the one peeking started from. Keeping it isn't offered:
  /// it would only mark the photo as reviewed.
  func isPeekedNeighbor(_ photoID: String) -> Bool { peek.map { $0.anchorID != photoID } ?? false }

  // Dev-panel / edge-state toggles
  @Published var limitedAccess: Bool = false
  @Published var emptyLibrary: Bool = false
  @Published var lowInventoryOverride: Bool = false
  var maxAvailable: Int {
    lowInventoryOverride ? 4 : eligiblePhotoCount
  }

  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

  private let library: PhotoLibraryServicing
  let pinnedAlbums: PinnedAlbumsViewModel
  private var pinnedAlbumsObservation: AnyCancellable?
  private var pickedAssets: [String: PHAsset] = [:]  // photo.id -> PHAsset, for real deletion
  @Published private var peekedPhotos: [String: SessionPhoto] = [:]  // asset id -> neighbor not in the deck
  private var deletedBytes: Int64 = 0
  /// Source of the photos not yet loaded into `photos`; `nil` once it runs dry.
  private var assetSource: (any AssetBatching)?
  private var sessionBatchSize = SessionViewModel.defaultCheckInInterval
  private var isLoadingBatch = false
  /// Batches of unreviewed photos kept loaded ahead of the current card.
  private static let lookaheadBatches = 2
  /// How long each decision stays on screen before it's recorded; unlisted ones record at once.
  private static let decisionHolds: [ReviewDecision: Duration] = [
    .convertToStill: .milliseconds(450)
  ]
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
    pinnedAlbums = PinnedAlbumsViewModel(library: library, store: pinnedAlbumsStore)
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
  /// The photo the review card shows: the one peeking started from, else the active photo.
  var cardPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.anchorID) } ?? currentPhoto }
  /// The photo the review controls act on: the peeked-at neighbor, else the active photo.
  var focusedPhoto: SessionPhoto? { peek.flatMap { photo(withID: $0.focusedID) } ?? currentPhoto }
  var peekNeighbors: [SessionPhoto] { (peek?.neighborIDs ?? []).compactMap(photo(withID:)) }
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
    pendingNewAlbums = []
    albumAssignedCount = 0
    initialAlbumMembership = [:]
    recentAlbumIDs = Self.loadPersistedRecentAlbumIDs()
    stagedAdditions = [:]
    stagedRemovals = [:]
    screen = .review
    prefetchNextPhoto()
    persistState()
  }

  private func sessionPhotos(from assets: [PHAsset], startingAt offset: Int) -> [SessionPhoto] {
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
  private func applyConversions(
    _ conversions: [SessionPhoto], stillIdentifiers: [String: String],
    originalSizes: [String: Int64]
  ) async {
    for photo in conversions {
      guard let newIdentifier = stillIdentifiers[photo.id],
        let index = photos.firstIndex(where: { $0.id == photo.id })
      else { continue }
      let newAsset = PHAsset.fetchAssets(withLocalIdentifiers: [newIdentifier], options: nil)
        .firstObject
      photos[index].assetIdentifier = newIdentifier
      photos[index].isLivePhoto = false
      photos[index].decision = .keep
      if let newAsset { pickedAssets[photo.id] = newAsset }
      let bytesSaved = await spaceFreed(originalSize: originalSizes[photo.id], newAsset: newAsset)
      statsStore.recordLivePhotoConversion(bytesSaved: bytesSaved)
      convertedLivePhotoCount += 1
    }
  }

  /// Space the dropped video frees. A missing size counts as zero.
  private func spaceFreed(originalSize: Int64?, newAsset: PHAsset?) async -> Int64 {
    guard let originalSize, let newAsset, let newSize = await library.storageSize(of: [newAsset])
    else { return 0 }
    return max(originalSize - newSize, 0)
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

  func toggleFavorite(id: String) {
    guard let i = photos.firstIndex(where: { $0.id == id }) else { return }
    photos[i].isFavorite.toggle()
  }

  // MARK: Album assignment

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
    guard initialAlbumMembership[photoID] == nil,
      let assetID = photo(withID: photoID)?.assetIdentifier
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
    haptics.albumToggle()
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

  /// A random eligible photo's date, for starting a `.date` session without picking one.
  func randomAssetDate() async -> Date? { await library.randomAssetDate() }

  // MARK: Peek

  /// Starts browsing the library neighbors of the active photo, once they load. The review
  /// controls act on the focused neighbor until `endPeek()`.
  func beginPeek() {
    guard peek == nil, let anchor = currentPhoto else { return }
    peek = PeekState(anchorID: anchor.id)
    loadPeekNeighbors()
  }

  /// Leaves peeking; the active photo is the review card's photo again.
  func endPeek() {
    peek = nil
  }

  func togglePeek() {
    if isPeeking { endPeek() } else { beginPeek() }
  }

  /// Points the review controls at a peeked neighbor. Reaching the photo at either end of
  /// the strip loads more on that side.
  func focusPeek(on photoID: String) {
    guard let state = peek, state.neighborIDs.contains(photoID) else { return }
    peek?.focusedID = photoID
    for side in state.edgeSides(of: photoID) { loadMorePeek(side) }
  }

  /// Adds photos to one side of the strip, keeping the focused photo.
  func loadMorePeek(_ side: PeekSide) {
    guard var state = peek, state.canLoad(side), !state.isLoading else { return }
    state.widen(side)
    peek = state
    loadPeekNeighbors()
  }

  private func loadPeekNeighbors() {
    guard let state = peek else { return }
    let (older, newer) = (state.olderCount, state.newerCount)
    Task {
      let neighbors = await neighborPhotos(of: state.anchorID, before: older, after: newer)
      guard peek?.anchorID == state.anchorID, peek?.isCurrentWindow(older: older, newer: newer) == true
      else { return }
      peek?.finishLoading(neighborIDs: neighbors.map(\.id))
    }
  }

  /// Up to `before` older and `after` newer photos around `photoID`'s asset, by the library's own
  /// creation-date order — independent of the session's fetch order. Includes the photo
  /// itself. Neighbors outside the deck stay off it until decided. Empty if the photo
  /// has no real `PHAsset` (mock/preview data).
  func neighborPhotos(of photoID: String, before: Int, after: Int) async -> [SessionPhoto] {
    guard let asset = pickedAssets[photoID] else { return [] }
    let neighbors = await library.neighborAssets(of: asset.localIdentifier, before: before, after: after)
    let deck = Dictionary(photos.map { ($0.assetIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    return neighbors.map { neighbor in
      let id = neighbor.localIdentifier
      if let inDeck = deck[id] { return inDeck }
      if let peeked = peekedPhotos[id] { return peeked }
      let peeked = sessionPhotos(from: [neighbor], startingAt: 0)[0]
      peekedPhotos[id] = peeked
      return peeked
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

  /// Applies everything staged this session as one library transaction: still copies
  /// of converted Live Photos, album changes, and deletions. All of it happens or none
  /// of it does, behind a single system prompt.
  func confirmDeletion() async {
    let toDelete = pendingItems
    let conversions = pendingConversions.filter { pickedAssets[$0.id] != nil }
    let keptNow = keptCount

    // Album changes on a photo that's being deleted are moot.
    let deletedIDs = Set(toDelete.map(\.id))
    let additions = stagedAdditions.filter { !deletedIDs.contains($0.key) }
    let removals = stagedRemovals.filter { !deletedIDs.contains($0.key) }
    let changes = SessionLibraryChanges(
      deletions: toDelete.compactMap { pickedAssets[$0.id] },
      conversions: conversions.reduce(into: [String: PHAsset]()) { $0[$1.id] = pickedAssets[$1.id] },
      albumAdditions: additions, albumRemovals: removals, albumAssets: pickedAssets)

    if !changes.isEmpty {
      isDeleting = true
      deletionError = nil

      // Sizes must be read before the originals are deleted.
      let bytes = await library.storageSize(of: changes.deletions) ?? 0
      var originalSizes: [String: Int64] = [:]
      for (photoID, asset) in changes.conversions {
        originalSizes[photoID] = await library.storageSize(of: [asset])
      }
      let result = await library.commitSessionChanges(changes)
      isDeleting = false

      switch result {
      case .success(let outcome):
        await applyConversions(
          conversions, stillIdentifiers: outcome.stillIdentifiers, originalSizes: originalSizes)
        pinnedAlbums.pin(outcome.createdAlbumIDs.sorted())
        if !outcome.createdAlbumIDs.isEmpty {
          Task { await refreshLibraryAlbumsIfLoaded() }
        }
        albumAssignedCount = additions.count
        stagedAdditions = [:]
        stagedRemovals = [:]
        pendingNewAlbums = []
        deletedCount = toDelete.count
        deletedBytes = bytes
        photos.removeAll { deletedIDs.contains($0.id) }
        history.removeAll()  // reversible window closes here

        guard conversions.allSatisfy({ outcome.stillIdentifiers[$0.id] != nil }) else {
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
    clearPersistedState()
    eligiblePhotoCount = library.totalEligibleAssetCount()
    recordReviewedPhotos()
    recordSessionStats(kept: keptNow, deleted: deletedCount)
  }

  /// Folds a finished session's decisions into the persisted lifetime
  /// stats via `statsStore`, which also logs a snapshot for debugging.
  private func recordSessionStats(kept: Int, deleted: Int) {
    statsStore.recordSession(kept: kept, deleted: deleted, bytesDeleted: deletedBytes)
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
}
