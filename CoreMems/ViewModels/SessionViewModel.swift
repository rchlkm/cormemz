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
  @Published var folders: [Folder] = [
    Folder(id: "doggo", name: "DOGGO", emoji: "🐶"),
    Folder(id: "travel", name: "Travel", emoji: "✈️"),
    Folder(id: "family", name: "Family", emoji: "👨‍👩‍👧"),
  ]
  @Published var deletedCount: Int = 0
  @Published var isDeleting: Bool = false
  @Published var deletionError: String?
  @Published var isConvertingLivePhoto: Bool = false
  @Published var livePhotoConversionError: String?
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
  static let checkInIntervalRange = 5...100
  private static let checkInIntervalDefaultsKey = "cm_checkInInterval"
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
  private let persistence: SessionPersisting
  private let haptics: HapticsServicing
  private let metadataService: PhotoMetadataServicing
  private let statsStore: LifetimeStatsServicing

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
    statsStore: LifetimeStatsServicing = LifetimeStatsService()
  ) {
    self.library = library
    self.persistence = persistence
    self.haptics = haptics
    self.metadataService = metadataService
    self.statsStore = statsStore
    let storedInterval =
      UserDefaults.standard.object(forKey: Self.checkInIntervalDefaultsKey) as? Int
    self.checkInInterval =
      storedInterval.map {
        min(max($0, Self.checkInIntervalRange.lowerBound), Self.checkInIntervalRange.upperBound)
      } ?? Self.defaultCheckInInterval
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
    let assets: [PHAsset]
    switch mode {
    case .shuffle:
      assets = await library.fetchRandomEligibleAssets(limit: limit)
    case .recent:
      assets = await library.fetchMostRecentEligibleAssets(limit: limit)
    case .date:
      let sinceDate = startDate ?? .distantPast
      assets = Array(await library.fetchEligibleAssets(since: sinceDate).prefix(limit))
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
    screen = .review
    prefetchNextPhoto()
    persistState()
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

  /// Opens the Photos app directly to the asset behind this photo,
  /// via the `photos-redirect://` URL scheme.
  /// Mock/preview asset identifiers don't resolve to anything,
  /// so this silently no-opp like opening any other unresolvable URL.
  func showInPhotosApp(assetIdentifier: String) {
    let uuid = assetIdentifier.components(separatedBy: "/").first ?? assetIdentifier
    guard let url = URL(string: "photos-redirect://\(uuid)") else { return }
    print("showInPhotosApp url", url)
    Task { @MainActor in
      UIApplication.shared.open(url)
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

  func toggleTag(photoID: String, folderID: String) {
    guard let i = photos.firstIndex(where: { $0.id == photoID }) else { return }
    if photos[i].tagFolderIDs.contains(folderID) {
      photos[i].tagFolderIDs.remove(folderID)
    } else {
      photos[i].tagFolderIDs.insert(folderID)
    }
  }

  func createFolder(name: String, emoji: String, assignToPhotoID: String?) {
    let folder = Folder(id: UUID().uuidString, name: name, emoji: emoji)
    folders.append(folder)
    if let photoID = assignToPhotoID {
      toggleTag(photoID: photoID, folderID: folder.id)
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

  /// Submits only the currently pending-delete assets
  func confirmDeletion() async {
    let toDelete = pendingItems
    let keptNow = keptCount
    guard !toDelete.isEmpty else {
      deletedCount = 0
      haptics.sessionComplete()
      screen = .completion
      clearPersistedState()
      recordSessionStats(kept: keptNow, deleted: 0)
      return
    }

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
      haptics.sessionComplete()
      screen = .completion
      clearPersistedState()
      recordSessionStats(kept: keptNow, deleted: toDelete.count)
    case .failure(let error):
      // Failed deletion must be surfaced without falsely reporting
      // success, and must not corrupt unrelated session state
      // (Invariant #5) — we simply leave `photos`/`history` untouched.
      deletionError = error.localizedDescription
    }
  }

  /// Folds a finished session's decisions into the persisted lifetime
  /// stats via `statsStore`, which also logs a snapshot for debugging.
  private func recordSessionStats(kept: Int, deleted: Int) {
    statsStore.recordSession(kept: kept, deleted: deleted)
  }

  func exitToHome() {
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
      historyAdvanced: history.map(\.advancedIndex)
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
