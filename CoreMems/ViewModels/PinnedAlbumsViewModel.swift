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

/// The user's pinned albums, which drive the review quick-access strip and the
/// Pinned Albums settings screen. `identifiers` is the order the user arranged.
@MainActor
final class PinnedAlbumsViewModel: ObservableObject {
  @Published private(set) var identifiers: [String]
  /// Every user album, for the settings screen to browse. Loaded on demand.
  @Published private(set) var albums: [AlbumOption] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isCreating = false
  @Published private(set) var creationError: String?

  @Published var sort: PinnedAlbumSort {
    didSet { defaults.set(sort.rawValue, forKey: Self.sortDefaultsKey) }
  }

  /// Called after an album is created, so other album lists can refresh.
  var onAlbumCreated: (() async -> Void)?

  private let library: PhotoLibraryServicing
  private let store: PinnedAlbumsStoring
  private let defaults: UserDefaults
  private static let sortDefaultsKey = "cm_pinnedAlbumSort"

  init(
    library: PhotoLibraryServicing, store: PinnedAlbumsStoring,
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
      let rank = Dictionary(
        recents.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
      return identifiers.enumerated()
        .sorted { (rank[$0.element] ?? .max, $0.offset) < (rank[$1.element] ?? .max, $1.offset) }
        .map(\.element)
    }
  }

  /// Always fetches the whole library: the settings screen is an infrequent visit.
  func load() {
    guard !isLoading else { return }
    isLoading = true
    identifiers = store.pinnedAlbumIdentifiers()
    Task {
      albums = await library.fetchAllUserAlbums()
      isLoading = false
    }
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

  /// Creates a real, empty Photos album and pins it. Unlike the review picker's pending
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
        albums.append(
          AlbumOption(ref: .existing(localIdentifier: newAlbumID), name: name, assetCount: 0))
        albums.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        await onAlbumCreated?()
      case .failure(let error):
        creationError = error.localizedDescription
      }
    }
  }
}

#if DEBUG
  extension PinnedAlbumsViewModel {
    /// A view model over in-memory doubles, for SwiftUI Previews.
    static func mock(albums: [AlbumOption] = [], pinned: [String] = []) -> PinnedAlbumsViewModel {
      let store = MockPinnedAlbumsStore()
      store.identifiers = pinned
      let model = PinnedAlbumsViewModel(
        library: MockPhotoLibraryService(), store: store,
        defaults: UserDefaults(suiteName: UUID().uuidString)!)
      model.albums = albums
      return model
    }
  }
#endif
