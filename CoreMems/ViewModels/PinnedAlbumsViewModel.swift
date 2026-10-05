// CoreMems/ViewModels/PinnedAlbumsViewModel.swift
import Combine
import Foundation

enum PinnedAlbumSort: String, CaseIterable, Identifiable {
  case myOrder
  case recentlyUsed

  var id: Self { self }

  var title: String {
    switch self {
    case .myOrder: return "My order"
    case .recentlyUsed: return "Recently used"
    }
  }
}

/// The pinned albums behind the quick-access strip and Pinned Albums settings.
/// `identifiers` is the order the user arranged.
@MainActor
final class PinnedAlbumsViewModel: ObservableObject {
  @Published private(set) var identifiers: [String]
  /// The user's album library: shared by Pinned Albums settings and the session's album
  /// picker/strip, so it's fetched once rather than by each independently.
  @Published private var catalog = AlbumCatalog()
  @Published private(set) var isLoading = false
  @Published private(set) var isCreating = false
  @Published private(set) var creationError: String?

  @Published var sort: PinnedAlbumSort {
    didSet { defaults.set(sort.rawValue, forKey: Self.sortDefaultsKey) }
  }

  /// Called after an album is created, so other album lists can refresh.
  var onAlbumCreated: (() async -> Void)?

  private let library: AlbumLibrary
  private let store: PinnedAlbumsStoring
  private let defaults: UserDefaults
  private static let sortDefaultsKey = "cm_pinnedAlbumSort"

  init(
    library: AlbumLibrary, store: PinnedAlbumsStoring,
    defaults: UserDefaults = .standard
  ) {
    self.library = library
    self.store = store
    self.defaults = defaults
    identifiers = store.pinnedAlbumIdentifiers()
    sort = defaults.string(forKey: Self.sortDefaultsKey).flatMap(PinnedAlbumSort.init) ?? .myOrder
  }

  /// `identifiers` arranged by `sort`; recency comes from `recents`, newest first.
  func orderedIdentifiers(recents: [String]) -> [String] {
    switch sort {
    case .myOrder:
      return identifiers
    case .recentlyUsed:
      let rank = recents.enumerated().indexed(by: \.element).mapValues(\.offset)
      return identifiers.enumerated()
        .sorted { (rank[$0.element] ?? .max, $0.offset) < (rank[$1.element] ?? .max, $1.offset) }
        .map(\.element)
    }
  }

  /// Every user album, for the settings screen and session to browse. Empty until loaded.
  var albums: [AlbumOption] { catalog.albums ?? [] }
  /// Every Photos folder of albums, for the settings screen and session to browse.
  var groups: [AlbumGroup] { catalog.groups }
  /// Whether the library has been fetched at least once.
  var isLoaded: Bool { catalog.isLoaded }

  /// Fires when the album list or folders load or change; a reload that finds nothing new
  /// stays silent.
  var libraryChanges: AnyPublisher<Void, Never> {
    $catalog.dropFirst().map { _ in }.eraseToAnyPublisher()
  }

  /// The albums for `identifiers`, in that order, skipping any not in the catalog.
  func albums(withIdentifiers identifiers: [String]) -> [AlbumOption] {
    catalog.albums(withIdentifiers: identifiers)
  }

  /// The folders containing each album or subfolder, outermost first, by identifier.
  var folderPathsByChildID: [String: [AlbumGroup]] { groups.folderPaths }

  /// Always fetches the whole library: an on-demand reload, not tied to how often a
  /// screen appears. Returns the task that finishes once loaded, or `nil` if a load is
  /// already in flight.
  @discardableResult
  func load() -> Task<Void, Never>? {
    guard !isLoading else { return nil }
    isLoading = true
    PinnedLoadTrace.log("load started")
    assign(\.identifiers, store.pinnedAlbumIdentifiers())
    return Task {
      async let fetchedAlbums = library.fetchAllUserAlbums()
      async let fetchedGroups = library.fetchAlbumGroups()
      let (newAlbums, newGroups) = await (fetchedAlbums, fetchedGroups)
      PinnedLoadTrace.log("fetched \(newAlbums.count) albums, \(newGroups.count) groups")
      if catalog.groups != newGroups { catalog.groups = newGroups }
      if catalog.albums == nil || catalog.albums! != newAlbums { catalog.albums = newAlbums }
      prune(albums: newAlbums)
      isLoading = false
      PinnedLoadTrace.log("load finished")
    }
  }

  /// Sets a published property only when it differs, so an unchanged reload doesn't redraw.
  private func assign<Value: Equatable>(
    _ keyPath: ReferenceWritableKeyPath<PinnedAlbumsViewModel, Value>, _ value: Value
  ) {
    if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
  }

  /// Unpins identifiers that aren't albums in a fetched library. An empty library changes
  /// nothing, so a failed or blocked fetch can't clear the pins.
  func prune(albums: [AlbumOption]) {
    guard !albums.isEmpty else { return }
    let existing = Set(albums.map(\.ref.identifier))
    let kept = identifiers.filter(existing.contains)
    guard kept.count < identifiers.count else { return }
    identifiers = kept
    store.setOrder(kept)
  }

  func toggle(_ identifier: String) {
    if identifiers.contains(identifier) {
      identifiers.removeAll { $0 == identifier }
      store.unpin(identifier)
    } else {
      pin([identifier])
    }
  }

  func pin(_ newIdentifiers: [String]) {
    identifiers += newIdentifiers.filter { !identifiers.contains($0) }
    store.pin(newIdentifiers)
  }

  /// Reorders `subset` within the pinned albums: they trade places among the slots they
  /// already occupy, so pinned albums outside `subset` stay where they are.
  func reorder(_ subset: [String]) {
    let members = subset.filter(identifiers.contains)
    let slots = Set(members)
    var reordered = members.makeIterator()
    identifiers = identifiers.map { slots.contains($0) ? reordered.next() ?? $0 : $0 }
    store.setOrder(identifiers)
  }

  /// Creates a real, empty Photos album and pins it. Unlike the browse picker's pending
  /// albums, there is no photo to wait on, so it is created right away.
  /// Returns the task that finishes once created, or `nil` if a creation is in flight.
  @discardableResult
  func createAndPin(name: String) -> Task<Void, Never>? {
    guard !isCreating else { return nil }
    isCreating = true
    creationError = nil
    return Task {
      let result = await library.createAlbum(named: name)
      isCreating = false
      switch result {
      case .success(let newAlbumID):
        pin([newAlbumID])
        var updated = catalog.albums ?? []
        updated.append(
          AlbumOption(ref: .existing(localIdentifier: newAlbumID), name: name, assetCount: 0))
        updated.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        catalog.albums = updated
        await onAlbumCreated?()
      case .failure(let error):
        creationError = error.localizedDescription
      }
    }
  }
}

#if DEBUG
  extension PinnedAlbumsViewModel {
    /// Seeds the album list directly, bypassing `load()`, for tests and previews.
    func setAlbums(_ albums: [AlbumOption]?) { catalog.albums = albums }

    /// A view model over in-memory doubles, for SwiftUI Previews.
    static func mock(
      albums: [AlbumOption] = [], groups: [AlbumGroup] = [], pinned: [String] = []
    ) -> PinnedAlbumsViewModel {
      let store = MockPinnedAlbumsStore()
      store.identifiers = pinned
      let model = PinnedAlbumsViewModel(
        library: MockPhotoLibraryService(), store: store,
        defaults: UserDefaults(suiteName: UUID().uuidString)!)
      model.catalog.groups = groups
      model.catalog.albums = albums
      return model
    }
  }
#endif
