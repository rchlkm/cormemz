// CoreMems/Views/Components/FailedEditsCard.swift
import SwiftUI

/// The edits Apply couldn't save. Tapping one opens it full screen with why it failed, to
/// try again or discard it; "Try all again" retries every one.
struct FailedEditsCard: View {
  let failures: [FailedEdit]
  /// Returns the edits still failing.
  let onRetry: ([String]) async -> [String: EditFailureReason]
  let onDiscard: (String) -> Void

  @State private var viewing: SessionPhoto?
  @State private var isRetryingAll = false
  @State private var retryAllError: String?

  private static let thumbnailSize: CGFloat = 64

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(
        "\(failures.count) edit\(failures.count == 1 ? "" : "s") couldn't be saved",
        systemImage: "exclamationmark.triangle.fill"
      )
      .font(.headline)
      .foregroundStyle(EditStyle.tint)

      Text("The originals were left unchanged. Tap one to see it and try again.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(failures) { failure in
            thumbnail(failure.photo)
          }
        }
      }

      if let retryAllError {
        Text(retryAllError)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Button {
        retryAll()
      } label: {
        if isRetryingAll {
          ProgressView()
        } else {
          Label(
            failures.count == 1 ? "Try again" : "Try all again", systemImage: "arrow.clockwise")
        }
      }
      .buttonStyle(ActionButtonStyle(role: .secondary))
      .disabled(isRetryingAll)
      .accessibilityIdentifier(AccessibilityID.failedEditsRetryAll)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardBackground()
    .fullScreenCover(item: $viewing) { photo in
      viewer(for: photo)
    }
  }

  /// Leads with the failure, then how the photo was decided and what the edit does.
  private func viewer(for photo: SessionPhoto) -> some View {
    let failure = failures.first { $0.id == photo.id }
    let decision = DecisionOverlay.content(for: photo.decision).title
    let summary = photo.activeEdit?.summary ?? ""
    // Once an unexplained failure repeats, giving up becomes the suggested action.
    let suggestsDiscard = failure.map { $0.reason == .unknown && $0.attempts > 1 } ?? false
    return FullScreenPhotoView(
      photo: photo,
      actions: [
        FullScreenPhotoAction(
          title: "Try again", systemImage: "arrow.clockwise",
          role: suggestsDiscard ? .secondary : .primary,
          accessibilityID: AccessibilityID.failedEditRetry,
          run: { await onRetry([photo.id])[photo.id]?.message }),
        FullScreenPhotoAction(
          title: "Discard edit", systemImage: "xmark",
          role: suggestsDiscard ? .primary : .secondary,
          accessibilityID: AccessibilityID.failedEditDiscard,
          run: {
            onDiscard(photo.id)
            return nil
          }),
      ],
      status: Self.notSavedStatus,
      statusDetail: summary.isEmpty ? decision : "\(decision) · \(summary)",
      message: failure?.reason.message)
  }

  private static var notSavedStatus: DecisionOverlay {
    DecisionOverlay(icon: "exclamationmark.triangle.fill", title: "Edit not saved", tint: EditStyle.tint)
  }

  private func thumbnail(_ photo: SessionPhoto) -> some View {
    AdaptiveAssetImage(
      photo: photo, targetSize: CGSize(width: Self.thumbnailSize, height: Self.thumbnailSize)
    )
    .rotated(quarterTurns: photo.previewQuarterTurns)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .onTapGesture { viewing = photo }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("View edit that couldn't be saved")
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier(AccessibilityID.failedEditPhoto)
  }

  private func retryAll() {
    isRetryingAll = true
    retryAllError = nil
    Task {
      let stillFailing = await onRetry(failures.map(\.id))
      retryAllError = stillFailing.isEmpty ? nil : Self.retryAllMessage(stillFailing)
      isRetryingAll = false
    }
  }

  /// The shared reason when every edit failed the same way, else a count.
  private static func retryAllMessage(_ stillFailing: [String: EditFailureReason]) -> String {
    let reasons = Set(stillFailing.values)
    if reasons.count == 1, let reason = reasons.first { return reason.message }
    return "\(stillFailing.count) still couldn't be saved. Tap one to see why."
  }
}
