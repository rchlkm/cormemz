// CoreMems/Models/MediaKind.swift
import Photos

/// What sets a photo or video apart from an ordinary one, shown as a badge on its full-screen
/// view. Live Photos play in place and have their own badge.
nonisolated enum MediaKind: CaseIterable, Equatable {
  case slowMo, timelapse, cinematic, panorama

  var subtype: PHAssetMediaSubtype {
    switch self {
    case .slowMo: return .videoHighFrameRate
    case .timelapse: return .videoTimelapse
    case .cinematic: return .videoCinematic
    case .panorama: return .photoPanorama
    }
  }

  var title: String {
    switch self {
    case .slowMo: return "SLO-MO"
    case .timelapse: return "TIME-LAPSE"
    case .cinematic: return "CINEMATIC"
    case .panorama: return "PANO"
    }
  }

  var symbol: String {
    switch self {
    case .slowMo: return "slowmo"
    case .timelapse: return "timelapse"
    case .cinematic: return "cinematic"
    case .panorama: return "pano"
    }
  }

  init?(subtypes: PHAssetMediaSubtype) {
    guard let kind = Self.allCases.first(where: { subtypes.contains($0.subtype) }) else {
      return nil
    }
    self = kind
  }
}

extension PHAsset {
  nonisolated var mediaKind: MediaKind? { MediaKind(subtypes: mediaSubtypes) }
}
