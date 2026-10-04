// CoreMems/ViewModels/SessionViewModel.swift
import Combine
import Foundation
import Photos

@MainActor
final class SessionViewModel: ObservableObject {

  // MARK: Published UI state
  @Published var screen: AppScreen = .home
  @Published var eligiblePhotoCount: Int = 0
  @Published private var deck = SessionDeck()
  @Published var isStartingSession: Bool = false
  /// Every user album, loaded once per app launch and refreshed on foreground return and
  /// after album creation. `nil` until loaded. Backed by `pinnedAlbums`'s catalog, so it's
  /// the same fetch Pinned Albums settings uses rather than a second one.
  var libraryAlbums: [AlbumOption]? {
    get { pinnedAlbums.isLoaded ? pinnedAlbums.albums : nil }
    set {
      #if DEBUG
        pinnedAlbums.setAlbums(newValue)
      #endif
    }
  }
  /// Photos folders of albums, loaded alongside `libraryAlbums`.
  var libraryAlbumGroups: [AlbumGroup] { pinnedAlbums.groups }
  @Published var albumAssignedCount: Int = 0
  /// Staged album adds/removes from this apply that no-op'd because the album no longer
  /// existed by the time the session was applied.
  @Published private(set) var missingAlbumCount: Int = 0
  /// Edits from this apply that couldn't be saved, kept for a retry.
  @Published private(set) var failedEdits: [FailedEdit] = []
  var failedEditCount: Int { failedEdits.count }
  @Published var deletedCount: Int = 0
  @Published private(set) var applyState: ApplyState = .idle
  var isDeleting: Bool { applyState == .applying }
  var deletionError: String? { applyState.failureMessage }
  @Published var convertedLivePhotoCount: Int = 0
  @Published private(set) var deletedBytes: Int64 = 0
  @Published private(set) var convertedBytesSaved: Int64 = 0
  @Published private(set) var trimmedBytesSaved: Int64 = 0
  @Published private(set) var editedCount: Int = 0

  /// The decision being shown before it's recorded; decisions and going back are ignored meanwhile.
  @Published private(set) var markingDecision: Decision?
  @Published var metadataForSheet: PhotoMetadata?
  @Published var isLoadingMetadata: Bool = false

  @Published private var settings: SessionSettings
  var checkInInterval: Int {
    get { settings.checkInInterval }
    set { settings.checkInInterval = newValue }
  }
  var includesKeptPhotos: Bool {
    get { settings.includesKeptPhotos }
    set { settings.includesKeptPhotos = newValue }
  }
  var tracksKeptHistory: Bool {
    get { settings.tracksKeptHistory }
    set { settings.tracksKeptHistory = newValue }
  }
  /// Which mode Home opens with.
  var defaultSessionMode: SelectionMode {
    get { settings.defaultSessionMode }
    set { settings.defaultSessionMode = newValue }
  }
  @Published private(set) var keptPhotoCount: Int = 0

  /// Where photos missing from the device may be downloaded from.
  var networkPolicy: NetworkPolicy {
    get { settings.networkPolicy }
    set {
      settings.networkPolicy = newValue
      networkAccess.policy = newValue
    }
  }
  /// False when the session may only show photos already on the device.
  @Published private(set) var allowsDownloads: Bool
  /// True when iOS's Low Data Mode is why downloads are blocked, regardless of `networkPolicy`.
  @Published private(set) var isLowDataModeActive: Bool

  /// Describes how the active session's photos were selected, shown as
  /// a subtitle under the browse progress line. `nil` for `.shuffle`.
  @Published var sessionLabel: String?

  // Dev-panel / edge-state toggles
  @Published var limitedAccess: Bool = false
  @Published var emptyLibrary: Bool = false
  @Published var lowInventoryOverride: Bool = false
  private static let lowInventoryCap = 4
  var maxAvailable: Int {
    lowInventoryOverride ? Self.lowInventoryCap : eligiblePhotoCount
  }

  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

  let library: PhotoLibraryServicing
  private let applyService: SessionApplyService
  let pinnedAlbums: PinnedAlbumsViewModel
  private var pinnedAlbumsObservation: AnyCancellable?
  /// Keeps `library`'s change observer registered for this view model's lifetime.
  private var libraryChangeObservation: AnyObject?
  private var pickedAssets: [String: PHAsset] = [:]  // photo.id -> PHAsset, for real deletion
  let peekController = PeekController()
  private var peekObservation: AnyCancellable?
  /// Source of the photos not yet loaded into `photos`; `nil` once it runs dry.
  private var assetSource: (any AssetBatching)?
  private var sessionBatchSize = SessionSettings.defaultCheckInInterval
  private var isLoadingBatch = false
  /// Batches of undecided photos kept loaded ahead of the current card.
  private static let lookaheadBatches = 2
  /// How long each decision stays on screen before it's recorded; unlisted ones record at once.
  private static let decisionHolds: [Decision: Duration] = [
    .convertToStill: .milliseconds(450)
  ]
  @Published private var albumStaging = AlbumStaging()
  @Published private var recentAlbums = RecentAlbums()
  private let persistence: SessionPersisting
  private let haptics: HapticsServicing
  private let metadataService: PhotoMetadataServicing
  private let statsStore: LifetimeStatsServicing
  private let keptPhotosStore: KeptPhotosStoring
  private let imageLoader: PhotoImageLoader
  private let networkAccess: NetworkAccessProviding
  private var networkSubscription: AnyCancellable?

  static let cardDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
  }()

  static let cardTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("jmmz")
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
    keptPhotosStore: KeptPhotosStoring = KeptPhotosStore(),
    settings: SessionSettings = SessionSettings(),
    imageLoader: PhotoImageLoader = .shared,
    networkAccess: NetworkAccessProviding = NetworkMonitor.shared
  ) {
    self.library = library
    self.persistence = persistence
    self.haptics = haptics
    self.metadataService = metadataService
    self.statsStore = statsStore
    self.settings = settings
    self.imageLoader = imageLoader
    self.networkAccess = networkAccess
    applyService = SessionApplyService(library: library)
    pinnedAlbums = PinnedAlbumsViewModel(library: library, store: pinnedAlbumsStore)
    self.keptPhotosStore = keptPhotosStore
    self.keptPhotoCount = keptPhotosStore.keptIdentifiers().count
    networkAccess.policy = settings.networkPolicy
    self.allowsDownloads = networkAccess.allowsDownloads
    self.isLowDataModeActive = networkAccess.isConstrained
    pinnedAlbums.onAlbumCreated = { [weak self] in await self?.refreshLibraryAlbumsIfLoaded() }
    libraryChangeObservation = library.observeLibraryChanges { [weak self] in
      Task { @MainActor in await self?.refreshLibraryAlbumsIfLoaded() }
    }
    // Only the state `quickAccessAlbums` reads re-renders this object's observers.
    pinnedAlbumsObservation = Publishers.Merge(
      pinnedAlbums.$identifiers.removeDuplicates().dropFirst().map { _ in },
      pinnedAlbums.$sort.removeDuplicates().dropFirst().map { _ in }
    ).sink { [weak self] in self?.objectWillChange.send() }
    peekController.loadNeighbors = { [weak self] anchorID, before, after in
      await self?.neighborPhotos(of: anchorID, before: before, after: after) ?? []
    }
    peekObservation = peekController.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
    }
    restoreIfInterrupted()
    networkSubscription = networkAccess.allowsDownloadsUpdates
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in self?.networkAccessChanged(allowsDownloads: $0) }
  }

  // MARK: Derived state

  var photos: [SessionPhoto] {
    get { deck.photos }
    set { deck.photos = newValue }
  }
  var currentIndex: Int {
    get { deck.currentIndex }
    set { deck.currentIndex = newValue }
  }
  var history: [DecisionHistoryEntry] { deck.history }
  var currentPhoto: SessionPhoto? { deck.currentPhoto }
  var pendingItems: [SessionPhoto] { deck.pendingItems }
  var pendingConversions: [SessionPhoto] { deck.pendingConversions }
  var pendingEdits: [SessionPhoto] { deck.pendingEdits }
  var markedPhotos: [SessionPhoto] { deck.markedPhotos }
  var keptCount: Int { deck.keptCount }
  var canGoBack: Bool { !deck.history.isEmpty && !isPeeking }

  // MARK: Session lifecycle

  /// Request/confirm authorization, then load the first batches of real
  /// assets in `mode`'s order, or fall back to mock data when running in
  /// previews/simulator without a populated library. A batch is
  /// `checkInInterval` photos; later batches load as the user browses.
  func startSession(
    mode: SelectionMode, startDate: Date?, album: AlbumOption? = nil,
    mediaTypes: Set<MediaType> = []
  ) async {
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
    let (source, assets) = await loadInitialAssets(
      mode: mode, startDate: startDate, albumIdentifier: album?.ref.identifier,
      mediaTypes: mediaTypes, count: initialCount, limit: limit)

    if !assets.isEmpty {
      deck = SessionDeck(photos: registerPhotos(from: assets))
      assetSource = assets.count < initialCount ? nil : source
    } else if allowsDownloads {
      // Preview/mock path — generates placeholder SessionPhoto data.
      deck = SessionDeck(photos: Self.mockPhotos(count: limit))
      assetSource = nil
    } else {
      deck = SessionDeck()
      assetSource = nil
    }
    sessionBatchSize = batchSize
    isLoadingBatch = false
    sessionLabel = mode.sessionLabel(
      startDateText: startDate.map(Self.cardDateFormatter.string(from:)), albumName: album?.name)
    resetSessionTotals()
    screen = .browse
    showApplyChangesIfDeckEmpty()
    prefetchNextPhoto()
    persistState()
  }

  /// Loads the first batch, skipping photos kept in earlier sessions. If that leaves nothing
  /// while the library has photos, loads without the skip rather than start an empty session.
  private func loadInitialAssets(
    mode: SelectionMode, startDate: Date?, albumIdentifier: String?,
    mediaTypes: Set<MediaType> = [], count: Int, limit: Int
  ) async -> (source: any AssetBatching, assets: [PHAsset]) {
    let kept = includesKeptPhotos ? [] : keptPhotosStore.keptIdentifiers()
    let source = await library.makeAssetSource(
      mode: mode, startDate: startDate, albumIdentifier: albumIdentifier,
      mediaTypes: mediaTypes, excluding: kept)
    let assets = await source.nextBatch(count: count)
    guard assets.isEmpty, !kept.isEmpty, limit > 0, library.totalEligibleAssetCount() > 0
    else { return (source, assets) }
    let unfiltered = await library.makeAssetSource(
      mode: mode, startDate: startDate, albumIdentifier: albumIdentifier,
      mediaTypes: mediaTypes, excluding: [])
    return (unfiltered, await unfiltered.nextBatch(count: count))
  }

  private func resetSessionTotals() {
    deletedCount = 0
    deletedBytes = 0
    convertedLivePhotoCount = 0
    convertedBytesSaved = 0
    trimmedBytesSaved = 0
    editedCount = 0
    failedEdits = []
    albumAssignedCount = 0
    albumStaging = AlbumStaging()
    recentAlbums = RecentAlbums()
  }

  /// Keeps each asset for later deletion and album changes, and returns a photo for it.
  private func registerPhotos(from assets: [PHAsset]) -> [SessionPhoto] {
    let photos = Self.makePhotos(from: assets)
    imageLoader.register(assets)
    for (photo, asset) in zip(photos, assets) {
      pickedAssets[photo.id] = asset
    }
    return photos
  }

  private static func makePhotos(from assets: [PHAsset]) -> [SessionPhoto] {
    assets.map { asset in
      SessionPhoto(
        id: asset.localIdentifier,
        assetIdentifier: asset.localIdentifier,
        previewURL: nil,
        isFavorite: asset.isFavorite,
        isLivePhoto: asset.mediaSubtypes.contains(.photoLive),
        isVideo: asset.mediaType == .video,
        dateLabel: asset.creationDate.map(cardDateFormatter.string) ?? "",
        timeLabel: asset.creationDate.map(cardTimeFormatter.string) ?? ""
      )
    }
  }

  /// Loads another batch whenever fewer than `lookaheadBatches` batches of
  /// photos remain ahead of the current card.
  private func loadMoreIfNeeded() {
    let batchSize = min(sessionBatchSize, remainingSessionCapacity)
    guard let source = assetSource, !isLoadingBatch, batchSize > 0,
      deck.remainingCount < Self.lookaheadBatches * sessionBatchSize
    else { return }
    isLoadingBatch = true
    Task {
      let assets = await source.nextBatch(count: batchSize)
      guard source === assetSource else { return }
      isLoadingBatch = false
      let alreadyInDeck = Set(deck.photos.map(\.assetIdentifier))
      let fresh = assets.filter { !alreadyInDeck.contains($0.localIdentifier) }
      deck.append(registerPhotos(from: fresh))
      if assets.count < batchSize { assetSource = nil }
      prefetchNextPhoto()
      showApplyChangesIfDeckEmpty()
      loadMoreIfNeeded()
      persistState()
    }
  }

  private var remainingSessionCapacity: Int {
    max(SessionSettings.maxPhotosPerSession - deck.photos.count, 0)
  }

  /// Whether every photo the session may load has been decided.
  var reachedSessionCap: Bool { deck.isExhausted && remainingSessionCapacity == 0 }

  /// An empty deck only means the session is over once no more photos can arrive.
  private func showApplyChangesIfDeckEmpty() {
    guard deck.isExhausted, assetSource == nil || remainingSessionCapacity == 0,
      screen == .browse
    else { return }
    endPeek()
    screen = .pendingChanges
  }

  /// Jumps straight to Apply Changes regardless of how many photos are
  /// left — the check-in overlay's "I'm done for now" and the browse
  /// top bar's Done button both go through here.
  func finishEarly() {
    guard screen == .browse else { return }
    endPeek()
    screen = .pendingChanges
    persistState()
  }

  // MARK: Keep / Delete / Go back

  /// Records a decision for the photo at `index`, first showing it for its hold in
  /// `decisionHolds`, if any. Recording advances the browse index if it's the active
  /// photo — matches the swipe/tap gesture path. Restoring an earlier photo from the
  /// Tray goes through `restoreMany` instead, which never advances index.
  /// Returns the task that finishes once recorded, or `nil` if the decision was ignored.
  @discardableResult
  func decide(index: Int, decision: Decision) -> Task<Void, Never>? {
    guard markingDecision == nil, deck.accepts(decision, at: index) else { return nil }
    guard decision != .convertToStill || canConvertToStill(deck.photos[index]) else { return nil }

    haptics.decided(decision)

    guard let hold = Self.decisionHolds[decision] else {
      record(index: index, decision: decision)
      return Task {}
    }
    markingDecision = decision
    let photoID = deck.photos[index].id
    return Task {
      try? await Task.sleep(for: hold)
      markingDecision = nil
      guard let index = deck.index(ofPhotoID: photoID) else { return }
      record(index: index, decision: decision)
    }
  }

  /// Decides on the photo with this id — the active photo, a photo ahead in the deck, or a
  /// peeked neighbor. Anything but the active photo joins the decided part of the deck
  /// without moving the active photo. Peeked neighbors can't be kept.
  @discardableResult
  func decide(photoID: String, decision: Decision) -> Task<Void, Never>? {
    guard markingDecision == nil,
      decision != .keep || !isPeekedNeighbor(photoID), let photo = photo(withID: photoID),
      photo.canReceive(decision),
      decision != .convertToStill || canConvertToStill(photo),
      let index = adoptIntoDecided(photoID)
    else { return nil }
    return decide(index: index, decision: decision)
  }

  /// Stages `edit` on the photo; it's written on Apply unless the photo ends up marked. An
  /// undecided photo stays undecided, and a marked one goes back to Keep, since editing it
  /// means keeping it. A peeked neighbor joins the deck behind the active card.
  /// Returns whether the edit was staged.
  @discardableResult
  func saveEdit(_ edit: MediaEdit, photoID: String) -> Bool {
    guard !edit.isEmpty, photo(withID: photoID) != nil else { return false }
    if deck.index(ofPhotoID: photoID) == nil, let peeked = peekController.take(photoID: photoID) {
      _ = deck.insertDecided(peeked)
    }
    if deck.photo(withID: photoID)?.decision.isMarked == true {
      deck.restoreMarkedToKeep(ids: [photoID])
    }
    guard deck.setEdit(edit, photoID: photoID) else { return false }
    haptics.albumToggle()
    if let asset = pickedAssets[photoID] { library.prepareEdit(edit, for: asset) }
    persistState()
    return true
  }

  /// The length in seconds of a video that can be trimmed; `nil` for anything else.
  func trimmableDuration(of photo: SessionPhoto) -> Double? {
    guard photo.isVideo, let asset = pickedAssets[photo.id], asset.isTrimmable, asset.duration > 0
    else { return nil }
    return asset.duration
  }

  /// A Live Photo can be converted when its original is on the device or may be downloaded.
  func canConvertToStill(_ photo: SessionPhoto) -> Bool {
    guard photo.isLivePhoto else { return false }
    guard !allowsDownloads, let asset = pickedAssets[photo.id] else { return true }
    return library.hasLocalOriginal(asset)
  }

  /// Moves a photo that isn't the active card — an unloaded neighbor or one ahead in the
  /// deck — in front of it, counting it as decided. Returns the photo's deck index.
  private func adoptIntoDecided(_ photoID: String) -> Int? {
    if let index = deck.adoptIntoDecided(photoID: photoID) { return index }
    guard let peeked = peekController.take(photoID: photoID) else { return nil }
    return deck.insertDecided(peeked)
  }

  /// A deck photo or a peeked neighbor.
  func photo(withID photoID: String) -> SessionPhoto? {
    deck.photo(withID: photoID) ?? peekController.photo(withID: photoID)
  }

  private func record(index: Int, decision: Decision) {
    guard let advanced = deck.record(index: index, decision: decision) else { return }
    if advanced {
      prefetchNextPhoto()
      loadMoreIfNeeded()
    }
    showApplyChangesIfDeckEmpty()
    persistState()
  }

  /// Steps back one decision (swipe left / back button). The photo keeps its decision so it
  /// can be changed on purpose. `history` is cleared on confirmation, so nothing confirmed
  /// can be stepped back onto.
  func goBack() {
    guard markingDecision == nil, let advanced = deck.goBack() else { return }
    if advanced { prefetchNextPhoto() }
    haptics.goBack()
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

  /// Favoriting doesn't decide a photo, so a peeked neighbor stays where it is.
  private func setFavoriteLocally(_ photoID: String, _ isFavorite: Bool) {
    if !deck.setFavorite(isFavorite, photoID: photoID) {
      peekController.setFavorite(isFavorite, photoID: photoID)
    }
  }

  /// Toggles whether the photo is left out of the kept history, so a later session shows it again.
  func toggleHeldForLater(photoID: String) {
    guard let photo = photo(withID: photoID) else { return }
    let isHeld = !photo.isHeldForLater
    if !deck.setHeldForLater(isHeld, photoID: photoID) {
      peekController.setHeldForLater(isHeld, photoID: photoID)
    }
    haptics.albumToggle()
    persistState()
  }

  /// Repoints each converted photo at its still copy as a plain keep and records the
  /// space freed by dropping the video.
  private func applyConversions(_ conversions: [SessionPhoto], from applied: SessionApplyResult) {
    for photo in conversions {
      guard let still = applied.stills[photo.id],
        deck.applyConversion(photoID: photo.id, stillIdentifier: still.identifier)
      else { continue }
      if let asset = still.asset { pickedAssets[photo.id] = asset }
      statsStore.recordLivePhotoConversion(bytesSaved: still.bytesSaved)
      convertedLivePhotoCount += 1
      convertedBytesSaved += still.bytesSaved
    }
  }

  private func recordTrimSavings(_ bytes: Int64) {
    guard bytes > 0 else { return }
    statsStore.recordTrimSavings(bytes: bytes)
    trimmedBytesSaved += bytes
  }

  /// Restores any number of marked photos to Keep and discards edits; powers the Marked
  /// Photos tray and the end-of-session grids.
  func restoreMany(ids: [String]) {
    guard !ids.isEmpty else { return }
    if deck.restoreMarkedToKeep(ids: Set(ids)) {
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
    return pinnedAlbums.albums(withIdentifiers: pinned + recentAlbumIDs.filter { !pinned.contains($0) })
  }

  /// Pinned albums as displayed, in their sort order (empty until the library loads).
  var pinnedDisplayItems: [PinnedDisplayItem] {
    PinnedDisplayItem.items(
      identifiers: orderedPinnedAlbumIDs, albums: pinnedAlbums.albums, groups: pinnedAlbums.groups)
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
    guard !pinnedAlbums.isLoaded else { return }
    await refreshLibraryAlbums()
  }

  /// `pinnedAlbums.load()` also prunes pins no longer in the library.
  func refreshLibraryAlbums() async {
    if let task = pinnedAlbums.load() { await task.value }
  }

  /// Re-reads access, the photo count and the album list.
  func refreshLibrary() async {
    refreshAuthorizationStatus()
    await refreshLibraryAlbums()
  }

  /// Refreshes only once a list is loaded; called when `library` reports the Photos
  /// library changed, and after a pending album is created.
  func refreshLibraryAlbumsIfLoaded() async {
    guard pinnedAlbums.isLoaded else { return }
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

  /// Creates a not-yet-real album, optionally staging it onto one photo right away
  /// (which also makes it a recent).
  func createPendingAlbum(name: String, assignToPhotoID: String?) {
    albumStaging.createPendingAlbum(name: name, assignTo: assignToPhotoID)
    if assignToPhotoID != nil, let created = pendingNewAlbums.last {
      recentAlbums.record(created.ref.identifier)
    }
    persistState()
  }

  /// A random eligible photo's date, for starting a `.date` session without picking one.
  func randomAssetDate() async -> Date? { await library.randomAssetDate() }

  // MARK: Peek

  /// Up to `before` older and `after` newer photos around `photoID`'s asset, by the library's own
  /// creation-date order — independent of the session's fetch order. Includes the photo
  /// itself. Neighbors outside the deck stay off it until decided. Empty if the photo
  /// has no real `PHAsset` (mock/preview data).
  func neighborPhotos(of photoID: String, before: Int, after: Int) async -> [SessionPhoto] {
    guard let asset = pickedAssets[photoID] else { return [] }
    let neighbors = await library.neighborAssets(of: asset.localIdentifier, before: before, after: after)
    let deckByAsset = Dictionary(
      deck.photos.map { ($0.assetIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    return neighbors.map { neighbor in
      let id = neighbor.localIdentifier
      if let inDeck = deckByAsset[id] { return inDeck }
      if let peeked = peekController.cachedPhoto(forAssetID: id) { return peeked }
      let peeked = registerPhotos(from: [neighbor])[0]
      peekController.cache(peeked, forAssetID: id)
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
      } else if let photo = deck.photo(withID: photoID) {
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
    guard let next = deck.nextPhoto, next.previewURL == nil else { return }
    Task {
      await imageLoader.prefetchNext(
        identifier: next.assetIdentifier, targetSize: Self.prefetchTargetSize)
    }
  }

  // MARK: Network access

  private func networkAccessChanged(allowsDownloads allowed: Bool) {
    allowsDownloads = allowed
    isLowDataModeActive = networkAccess.isConstrained
    if !allowed { dropPhotosNeedingDownloadAhead() }
  }

  /// Removes undecided photos from the deck ahead of the current card that can't be
  /// shown without downloading. They stay undecided, so a later session offers them again.
  private func dropPhotosNeedingDownloadAhead() {
    let candidates = photos.dropFirst(currentIndex)
      .filter { $0.decision == .undecided }
      .compactMap { photo in pickedAssets[photo.id].map { (id: photo.id, asset: $0) } }
    guard !candidates.isEmpty else { return }
    let library = library
    Task {
      // Concurrent, matching FilteringAssetSource's own admission probing — each candidate
      // is an independent PHImageManager lookup, so probing serially pays that latency once
      // per photo in a row.
      let unavailable = await withTaskGroup(of: (id: String, isUnavailable: Bool).self) { group in
        for candidate in candidates {
          group.addTask {
            (candidate.id, await !library.isDisplayableWithoutNetwork(candidate.asset))
          }
        }
        var unavailable = Set<String>()
        for await result in group where result.isUnavailable {
          unavailable.insert(result.id)
        }
        return unavailable
      }
      guard !allowsDownloads, !unavailable.isEmpty else { return }
      let boundary = currentIndex
      photos = photos.enumerated().filter { index, photo in
        index < boundary || photo.decision != .undecided || !unavailable.contains(photo.id)
      }.map(\.element)
      prefetchNextPhoto()
      loadMoreIfNeeded()
      showApplyChangesIfDeckEmpty()
      persistState()
    }
  }

  // MARK: Confirm and Delete

  /// Applies everything staged this session as one library transaction: still copies
  /// of converted Live Photos, edits, album changes, and deletions. All of it happens or none
  /// of it does, behind a single system prompt.
  func applyChanges() async {
    let plan = SessionChangePlan(deck: deck, assets: pickedAssets, staging: albumStaging)

    if !plan.changes.isEmpty {
      guard await applyPlan(plan) else { return }
    }
    editedCount = plan.editedCount - failedEditCount

    // A failed edit needs attention, so it takes the place of the completion feedback.
    if failedEdits.isEmpty { haptics.sessionComplete() } else { haptics.editFailed() }
    screen = .completion
    persistence.clear()
    eligiblePhotoCount = library.totalEligibleAssetCount()
    recordKeptPhotos()
    statsStore.recordSession(
      kept: plan.keptCount, deleted: deletedCount, edited: editedCount, bytesDeleted: deletedBytes)
  }

  /// Runs the plan's changes as one library transaction and brings the session in line with the result.
  /// Returns whether the session can finish; on failure it stays open, as it was.
  private func applyPlan(_ plan: SessionChangePlan) async -> Bool {
    applyState = .applying
    let result = await applyService.apply(plan.changes)
    applyState = .idle

    switch result {
    case .success(let applied):
      applyConversions(plan.conversions, from: applied)
      markKept(applied.outcome.clipIdentifiers.values)
      recordTrimSavings(applied.bytesSavedByTrimming)
      let createdAlbumIDs = applied.outcome.createdAlbumIDs
      pinnedAlbums.pin(createdAlbumIDs.sorted())
      recentAlbums.forget(Set(pendingNewAlbums.map(\.ref.identifier)))
      createdAlbumIDs.sorted().forEach { recentAlbums.record($0) }
      recentAlbums.persist(excluding: [])
      if !createdAlbumIDs.isEmpty {
        Task { await refreshLibraryAlbumsIfLoaded() }
      }
      albumAssignedCount = plan.changes.albumAdditions.count
      missingAlbumCount = applied.outcome.missingAlbumIdentifiers.count
      failedEdits = deck.photos.compactMap { photo in
        applied.outcome.failedEdits[photo.id].map { FailedEdit(photo: photo, reason: $0) }
      }
      albumStaging.clearStaged()
      deletedCount = plan.deletions.count
      deletedBytes = applied.bytesDeleted
      deck.remove(photoIDs: Set(plan.deletions.map(\.id)))
      deck.clearHistory()  // reversible window closes here

      guard plan.conversions.allSatisfy({ applied.stills[$0.id] != nil }) else {
        applyState = .failed(PhotoLibraryError.creationFailed.localizedDescription)
        persistState()
        return false
      }
      return true
    case .failure(let error):
      // Declining the system prompt isn't an error, but the session stays open.
      if (error as? PHPhotosError)?.code != .userCancelled {
        applyState = .failed(error.localizedDescription)
      }
      return false
    }
  }

  /// Writes the failed edits among `photoIDs` again, as one transaction. Each one written
  /// leaves `failedEdits` and counts as edited; the rest record why they failed this time.
  /// Returns those still failing.
  @discardableResult
  func retryEdits(photoIDs: [String]) async -> [String: EditFailureReason] {
    let edits: [String: AssetEdit] = failedEdits.reduce(into: [:]) { byID, failed in
      guard photoIDs.contains(failed.id) else { return }
      byID[failed.id] = AssetEdit(photo: failed.photo, asset: pickedAssets[failed.id])
    }
    guard !edits.isEmpty else { return [:] }

    let failures: [String: EditFailureReason]
    switch await applyService.apply(SessionLibraryChanges(edits: edits)) {
    case .success(let applied):
      failures = applied.outcome.failedEdits
      markKept(applied.outcome.clipIdentifiers.values)
      recordTrimSavings(applied.bytesSavedByTrimming)
    case .failure(let error):
      let declined = (error as? PHPhotosError)?.code == .userCancelled
      failures = edits.mapValues { _ in declined ? .declined : .unknown }
    }

    let written = Set(edits.keys).subtracting(failures.keys)
    failedEdits = failedEdits.compactMap { failed in
      guard !written.contains(failed.id) else { return nil }
      guard let reason = failures[failed.id] else { return failed }
      var retried = failed
      retried.reason = reason
      retried.attempts += 1
      return retried
    }
    if !written.isEmpty {
      editedCount += written.count
      statsStore.recordEdits(written.count)
    }
    if failures.isEmpty { haptics.keep() } else { haptics.editFailed() }
    return failures
  }

  /// Gives up on a failed edit; its photo stays as it is in the library.
  func discardFailedEdit(photoID: String) {
    failedEdits.removeAll { $0.id == photoID }
  }

  /// Remembers the session's kept photos so later sessions skip them.
  /// Photos marked for deletion aren't recorded: they're either gone
  /// after applying, or if the session is abandoned, still undecided.
  /// Photos held for later are skipped too.
  private func recordKeptPhotos() {
    markKept(
      deck.keptPhotos
        .filter { pickedAssets[$0.id] != nil && !$0.isHeldForLater }
        .map(\.assetIdentifier))
  }

  /// Adds assets to the kept history, such as kept photos and the clips trimmed from them.
  private func markKept(_ identifiers: some Sequence<String>) {
    guard tracksKeptHistory else { return }
    keptPhotosStore.markKept(Set(identifiers))
    keptPhotoCount = keptPhotosStore.keptIdentifiers().count
  }

  /// Zeroes the lifetime stats; the next recorded activity restarts the tracking date.
  func clearLifetimeStats() {
    statsStore.clear()
    objectWillChange.send()
  }

  /// Makes every photo eligible for browsing again.
  func resetKeptPhotos() {
    keptPhotosStore.clear()
    keptPhotoCount = 0
  }

  func exitToSetup() {
    endPeek()
    recordKeptPhotos()
    persistence.clear()
    screen = .setup
  }

  func resetForAnotherSession() {
    screen = .setup
  }

  // MARK: Persistence

  /// Called on every decision so a backgrounded/killed app can resume
  /// exactly where the user left off
  private func persistState() {
    guard screen == .browse || screen == .pendingChanges else { return }
    persistence.save(
      PersistedSessionSnapshot(
        deck: deck, albumStaging: albumStaging))
  }

  /// Resolves the real assets, so deleting and filing into albums work on a resumed session.
  private func restorePickedAssets(for photos: [SessionPhoto]) {
    let resolved = PHAsset.fetchAssets(
      withLocalIdentifiers: photos.map(\.assetIdentifier), options: nil)
    var assetsByID: [String: PHAsset] = [:]
    resolved.enumerateObjects { asset, _, _ in assetsByID[asset.localIdentifier] = asset }
    for photo in photos {
      if let asset = assetsByID[photo.assetIdentifier] {
        pickedAssets[photo.id] = asset
      }
    }
    imageLoader.register(Array(assetsByID.values))
  }

  private func restoreIfInterrupted() {
    guard let snapshot = persistence.load() else { return }
    deck = snapshot.restoredDeck
    restorePickedAssets(for: deck.photos)
    albumStaging = snapshot.restoredAlbumStaging
    screen = deck.isExhausted ? .pendingChanges : .browse
    prefetchNextPhoto()
  }
}
