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

  init(
    library: PhotoLibraryServicing = PhotoLibraryService(),
    persistence: SessionPersisting = SessionPersistence(),
    haptics: HapticsServicing = HapticsService()
  ) {
    self.library = library
    self.persistence = persistence
    self.haptics = haptics
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

  /// Request/confirm authorization, fetch real assets,
  /// or fall back to mock data when running in previews
  /// simulator without a populated library.
  func startSession(requestedSize: Int) async {
    let status = await checkAuthorization()
    guard status == .authorized || status == .limited else {
      // Denied/restricted — bounce back to Home, where
      // `isAccessDenied` will now show the recovery screen instead
      // of silently doing nothing.
      screen = .home
      return
    }

    let capped = min(requestedSize, max(maxAvailable, 0))
    let assets = await library.fetchRandomEligibleAssets(limit: capped)

    if assets.isEmpty {
      // Preview/mock path — generates placeholder SessionPhoto data.
      photos = Self.mockPhotos(count: capped)
    } else {
      photos = assets.enumerated().map { idx, asset in
        let id = "\(asset.localIdentifier)-\(idx)"
        pickedAssets[id] = asset
        return SessionPhoto(
          id: id,
          assetIdentifier: asset.localIdentifier,
          previewURL: nil,
          isFavorite: asset.isFavorite
        )
      }
    }

    currentIndex = 0
    history = []
    deletedCount = 0
    screen = .review
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

    if advanced { currentIndex += 1 }

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
    if last.advancedIndex { currentIndex = last.photoIndex }
    haptics.undo()
    persistState()
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

  // MARK: Confirm and Delete

  /// Submits only the currently pending-delete assets
  func confirmDeletion() async {
    let toDelete = pendingItems
    guard !toDelete.isEmpty else {
      deletedCount = 0
      haptics.sessionComplete()
      screen = .completion
      clearPersistedState()
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
      haptics.confirmDelete()
      haptics.sessionComplete()
      screen = .completion
      clearPersistedState()
    case .failure(let error):
      // Failed deletion must be surfaced without falsely reporting
      // success, and must not corrupt unrelated session state
      // (Invariant #5) — we simply leave `photos`/`history` untouched.
      deletionError = error.localizedDescription
    }
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
  }

  // MARK: Mock data for previews / empty-library demos

  static func mockPhotos(count: Int) -> [SessionPhoto] {
    (0..<count).map { i in
      SessionPhoto(
        id: "mock-\(i)",
        assetIdentifier: "mock-asset-\(i)",
        previewURL: URL(string: "https://picsum.photos/seed/coremems-\(i)/420/580"),
        isFavorite: i % 4 == 1
      )
    }
  }
}
