// CoreMems/Services/LibraryCountDiagnostics.swift
#if DEBUG
  import Photos

  /// Debug-only report of how many assets PhotoKit returns under different fetch options, for
  /// comparing the app's library total with the Photos app's.
  nonisolated enum LibraryCountDiagnostics {
    static func makeReport() -> String {
      let image = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
      let video = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
      let everything = AssetBatchSource.mediaTypePredicate([])

      var lines = ["authorization: \(authorizationName)"]
      lines += [
        count("no predicate"),
        count("images", image),
        count("videos", video),
        count("app total", everything),
        count("app total + hidden", everything, hidden: true),
        count("app total + all burst frames", everything, bursts: true),
        count("hidden only", NSPredicate(format: "isHidden == YES"), hidden: true),
      ]
      lines += MediaType.allCases.map {
        count("filter: \($0)", AssetBatchSource.mediaTypePredicate([$0]))
      }
      lines += subtypeExclusionLines()
      lines += [
        count("source: user library", everything, sources: .typeUserLibrary),
        count("source: cloud shared", everything, sources: .typeCloudShared),
        count("source: iTunes synced", everything, sources: .typeiTunesSynced),
      ]
      lines += librarySmartAlbumLines(image: image, video: video)
      return lines.joined(separator: "\n")
    }

    private static var authorizationName: String {
      switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
      case .authorized: "full"
      case .limited: "limited"
      case .denied: "denied"
      case .restricted: "restricted"
      case .notDetermined: "not determined"
      @unknown default: "unknown"
      }
    }

    private static func count(
      _ label: String, _ predicate: NSPredicate? = nil, hidden: Bool = false, bursts: Bool = false,
      sources: PHAssetSourceType? = nil
    ) -> String {
      let options = PHFetchOptions()
      options.predicate = predicate
      options.includeHiddenAssets = hidden
      options.includeAllBurstAssets = bursts
      if let sources { options.includeAssetSourceTypes = sources }
      return "\(label): \(PHAsset.fetchAssets(with: options).count.formatted())"
    }

    /// Compares ways of excluding a subtype against the exact figure (all of a type minus those
    /// that have the subtype), since `(mediaSubtypes & bit) == 0` can miss assets.
    private static func subtypeExclusionLines() -> [String] {
      let cases: [(label: String, type: PHAssetMediaType, subtype: PHAssetMediaSubtype)] = [
        ("photos without screenshot", .image, .photoScreenshot),
        ("videos without timelapse", .video, .videoTimelapse),
      ]
      return cases.flatMap { label, type, subtype in
        let base = NSPredicate(format: "mediaType == %d", type.rawValue)
        let withSubtype = NSPredicate(
          format: "mediaType == %d AND (mediaSubtypes & %d) != 0", type.rawValue, subtype.rawValue)
        let equalsZero = NSPredicate(
          format: "mediaType == %d AND (mediaSubtypes & %d) == 0", type.rawValue, subtype.rawValue)
        let negated = NSPredicate(
          format: "mediaType == %d AND NOT ((mediaSubtypes & %d) != 0)", type.rawValue,
          subtype.rawValue)
        return [
          count("\(label): expected", total: fetchCount(base) - fetchCount(withSubtype)),
          count("\(label): == 0", total: fetchCount(equalsZero)),
          count("\(label): NOT != 0", total: fetchCount(negated)),
        ]
      }
    }

    private static func fetchCount(_ predicate: NSPredicate) -> Int {
      let options = PHFetchOptions()
      options.predicate = predicate
      return PHAsset.fetchAssets(with: options).count
    }

    private static func count(_ label: String, total: Int) -> String {
      "\(label): \(total.formatted())"
    }

    /// The Library smart album is the closest PhotoKit gets to what the Photos app shows.
    private static func librarySmartAlbumLines(image: NSPredicate, video: NSPredicate) -> [String]
    {
      guard
        let album = PHAssetCollection.fetchAssetCollections(
          with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil
        ).firstObject
      else { return ["Library album: unavailable"] }

      func albumCount(_ label: String, _ predicate: NSPredicate?) -> String {
        let options = PHFetchOptions()
        options.predicate = predicate
        return "Library album \(label): \(PHAsset.fetchAssets(in: album, options: options).count.formatted())"
      }
      return [
        albumCount("all", nil),
        albumCount("images", image),
        albumCount("videos", video),
        "Library album estimated: \(estimatedCountText(album))",
      ]
    }

    /// `estimatedAssetCount` is `NSNotFound` when PhotoKit has no estimate.
    private static func estimatedCountText(_ album: PHAssetCollection) -> String {
      let estimate = album.estimatedAssetCount
      return estimate == NSNotFound ? "unknown" : estimate.formatted()
    }
  }
#endif
