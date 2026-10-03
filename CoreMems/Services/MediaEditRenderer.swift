// CoreMems/Services/MediaEditRenderer.swift
import AVFoundation
import CoreImage
import Photos
import UniformTypeIdentifiers
import os

nonisolated enum MediaEditError: Error {
  case inputUnavailable
  case unsupportedMedia
}

/// Renders staged edits into Photos edit outputs ahead of Apply, so applying only has to
/// write them. Each asset keeps its latest render; a changed edit replaces it.
actor MediaEditRenderer {
  typealias Rendered = Result<PHContentEditingOutput, EditFailureReason>

  private struct Render {
    let edit: MediaEdit
    let task: Task<Rendered, Never>
  }

  private nonisolated static let logger = Logger(subsystem: "com.coremems", category: "editing")
  private static let adjustmentFormat = Bundle.main.bundleIdentifier ?? "CoreMems"
  private static let adjustmentFormatVersion = "1"

  private let networkAccess: NetworkAccessProviding
  private var renders: [String: Render] = [:]  // asset localIdentifier -> latest render

  init(networkAccess: NetworkAccessProviding) {
    self.networkAccess = networkAccess
  }

  /// Starts rendering `edit` in the background unless it's already rendering or rendered.
  func prepare(_ edit: MediaEdit, for asset: PHAsset) {
    _ = render(edit, for: asset)
  }

  /// The rendered edit, waiting on a render in progress or starting one. A failed render is
  /// retried once before its failure is returned.
  func output(for edit: MediaEdit, of asset: PHAsset) async -> Rendered {
    if case .success(let output) = await render(edit, for: asset).value { return .success(output) }
    renders[asset.localIdentifier] = nil
    return await render(edit, for: asset).value
  }

  func discardAll() {
    renders.values.forEach { $0.task.cancel() }
    renders.removeAll()
  }

  private func render(_ edit: MediaEdit, for asset: PHAsset) -> Task<Rendered, Never> {
    let id = asset.localIdentifier
    if let existing = renders[id], existing.edit == edit { return existing.task }
    renders[id]?.task.cancel()
    let allowsNetwork = networkAccess.allowsDownloads
    let task = Task.detached(priority: .utility) { () -> Rendered in
      do {
        return .success(try await Self.makeOutput(edit, for: asset, allowsNetwork: allowsNetwork))
      } catch {
        Self.logger.error("edit render failed for \(id, privacy: .public): \(error, privacy: .public)")
        return .failure(Self.reason(for: error, allowsNetwork: allowsNetwork))
      }
    }
    renders[id] = Render(edit: edit, task: task)
    return task
  }

  /// Without network access, an original that can't be read is assumed to be in iCloud.
  private nonisolated static func reason(for error: Error, allowsNetwork: Bool)
    -> EditFailureReason
  {
    if (error as? PHPhotosError)?.code == .networkAccessRequired { return .needsDownload }
    if !allowsNetwork, case MediaEditError.inputUnavailable = error { return .needsDownload }
    return .unknown
  }

  private nonisolated static func makeOutput(
    _ edit: MediaEdit, for asset: PHAsset, allowsNetwork: Bool
  ) async throws -> PHContentEditingOutput {
    let input = try await contentEditingInput(for: asset, allowsNetwork: allowsNetwork)
    let output = PHContentEditingOutput(contentEditingInput: input)
    output.adjustmentData = PHAdjustmentData(
      formatIdentifier: adjustmentFormat, formatVersion: adjustmentFormatVersion,
      data: try JSONEncoder().encode(edit))

    // The Live Photo context also accepts a still's input, then fails to save it.
    if input.mediaSubtypes.contains(.photoLive),
      let context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
    {
      let quarterTurns = edit.quarterTurns
      context.frameProcessor = { frame, _ in rotated(frame.image, quarterTurns: quarterTurns) }
      try await context.saveLivePhoto(to: output)
    } else if input.mediaType == .image {
      try renderPhoto(input, quarterTurns: edit.quarterTurns, to: output)
    } else if input.mediaType == .video {
      try await renderVideo(input, quarterTurns: edit.quarterTurns, to: output)
    } else {
      throw MediaEditError.unsupportedMedia
    }
    return output
  }

  /// Asks for the current version as rendered, so edits made in Photos are carried over and a
  /// later Revert there restores the original.
  private nonisolated static func contentEditingInput(
    for asset: PHAsset, allowsNetwork: Bool
  ) async throws -> PHContentEditingInput {
    let options = PHContentEditingInputRequestOptions()
    options.isNetworkAccessAllowed = allowsNetwork
    options.canHandleAdjustmentData = { _ in false }
    return try await withCheckedThrowingContinuation { continuation in
      asset.requestContentEditingInput(with: options) { input, _ in
        if let input {
          continuation.resume(returning: input)
        } else {
          continuation.resume(throwing: MediaEditError.inputUnavailable)
        }
      }
    }
  }

  private nonisolated static func renderPhoto(
    _ input: PHContentEditingInput, quarterTurns: Int, to output: PHContentEditingOutput
  ) throws {
    guard let url = input.fullSizeImageURL,
      let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    else { throw MediaEditError.inputUnavailable }

    // Orientation is baked into the pixels, so the written metadata must say "up".
    var properties = image.properties
    properties[kCGImagePropertyOrientation as String] = CGImagePropertyOrientation.up.rawValue
    if var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
      tiff[kCGImagePropertyTIFFOrientation as String] = CGImagePropertyOrientation.up.rawValue
      properties[kCGImagePropertyTIFFDictionary as String] = tiff
    }
    let result = rotated(image, quarterTurns: quarterTurns).settingProperties(properties)
    let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

    // Photos only accepts the rendered types it offers, which follow the original's format.
    let context = CIContext()
    let type = output.defaultRenderedContentType ?? .jpeg
    let renderedURL = try output.renderedContentURL(for: type)
    if type.conforms(to: .heic) {
      try context.writeHEIFRepresentation(
        of: result, to: renderedURL, format: .RGBA8, colorSpace: colorSpace)
    } else {
      try context.writeJPEGRepresentation(of: result, to: renderedURL, colorSpace: colorSpace)
    }
  }

  /// Rewrites only the video track's display transform; samples are copied as-is.
  private nonisolated static func renderVideo(
    _ input: PHContentEditingInput, quarterTurns: Int, to output: PHContentEditingOutput
  ) async throws {
    guard let source = input.audiovisualAsset else { throw MediaEditError.inputUnavailable }

    let composition = AVMutableComposition()
    for track in try await source.load(.tracks)
    where track.mediaType == .video || track.mediaType == .audio {
      guard
        let copy = composition.addMutableTrack(
          withMediaType: track.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { continue }
      let timeRange = try await track.load(.timeRange)
      try copy.insertTimeRange(timeRange, of: track, at: timeRange.start)
      if track.mediaType == .video {
        let (transform, naturalSize) = try await track.load(.preferredTransform, .naturalSize)
        copy.preferredTransform = rotatedTransform(
          transform, naturalSize: naturalSize, quarterTurns: quarterTurns)
      }
    }

    guard
      let export = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetPassthrough)
    else { throw MediaEditError.unsupportedMedia }
    try await export.export(to: try output.renderedContentURL(for: .quickTimeMovie), as: .mov)
  }

  /// `image` turned counterclockwise by `quarterTurns` quarter turns, with its origin at zero.
  nonisolated static func rotated(_ image: CIImage, quarterTurns: Int) -> CIImage {
    let orientations: [CGImagePropertyOrientation] = [.up, .left, .down, .right]
    let turned = image.oriented(orientations[quarterTurns % 4])
    return turned.transformed(
      by: CGAffineTransform(translationX: -turned.extent.minX, y: -turned.extent.minY))
  }

  /// `transform` followed by `quarterTurns` counterclockwise quarter turns, keeping the
  /// displayed frame at the origin.
  nonisolated static func rotatedTransform(
    _ transform: CGAffineTransform, naturalSize: CGSize, quarterTurns: Int
  ) -> CGAffineTransform {
    // One counterclockwise quarter turn in y-down coordinates, kept exact rather than via sin/cos.
    let quarterTurn = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
    let turned = (0..<(quarterTurns % 4)).reduce(transform) { result, _ in
      result.concatenating(quarterTurn)
    }
    let frame = CGRect(origin: .zero, size: naturalSize).applying(turned)
    return turned.concatenating(CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
  }
}
