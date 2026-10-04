// CoreMems/Views/Components/FullScreenPhotoView.swift
import SwiftUI

/// Full-screen photo viewer. Pinch to zoom in/out (persists — no
/// bounce-back — matching a normal photo viewer rather than the
/// card's "peek" zoom). While zoomed, dragging pans around the image.
/// While at 1x, dragging in any direction dismisses past a threshold,
/// or springs back to center if it doesn't clear it. Double-tap
/// toggles zoom as a shortcut.
struct FullScreenPhotoView: View {
  let photo: SessionPhoto
  /// Shown along the bottom under `status`, `statusDetail` and `message`.
  var actions: [FullScreenPhotoAction] = []
  var status: DecisionOverlay? = nil
  var statusDetail: String? = nil
  /// Shown until an action fails with its own message.
  var message: String? = nil

  @Environment(\.dismiss) private var dismiss
  @State private var runningActionTitle: String?
  @State private var actionError: String?

  @State private var zoom = ZoomPanState()

  var body: some View {
    ZStack {
      Color.black
        .opacity(zoom.backgroundOpacity)
        .ignoresSafeArea()

      AdaptiveAssetImage(
        photo: photo, targetSize: UIScreen.main.bounds.size, contentMode: .fit
      )
      .zoomPanDismiss($zoom) { dismiss() }
    }
    .overlay(alignment: .topTrailing) { closeButton.opacity(zoom.chromeOpacity) }
    .overlay(alignment: .bottom) { footer.opacity(zoom.chromeOpacity) }
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.photoViewer)
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .accessibilityLabel("Close")
    .disabled(zoom.isZoomed)
    .padding(16)
  }

  @ViewBuilder
  private var footer: some View {
    if !actions.isEmpty {
      VStack(spacing: 12) {
        if let status {
          Label {
            Text(status.title).foregroundStyle(.white)
          } icon: {
            Image(systemName: status.icon).foregroundStyle(status.tint)
          }
          .font(.headline)
        }
        if let statusDetail {
          Text(statusDetail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        if let shown = actionError ?? message {
          Text(shown)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        ForEach(actions, id: \.title) { action in
          Button {
            run(action)
          } label: {
            if runningActionTitle == action.title {
              ProgressView()
            } else {
              Label(action.title, systemImage: action.systemImage)
            }
          }
          .buttonStyle(ActionButtonStyle(role: action.role))
          .accessibilityIdentifier(action.accessibilityID)
          .disabled(zoom.isZoomed || runningActionTitle != nil)
        }
      }
      .environment(\.colorScheme, .dark)
      .padding(26)
      .padding(.top, 40)
      .frame(maxWidth: .infinity)
      .background(
        LinearGradient(
          stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.85), location: 0.35)],
          startPoint: .top, endPoint: .bottom)
      )
    }
  }

  private func run(_ action: FullScreenPhotoAction) {
    runningActionTitle = action.title
    actionError = nil
    Task {
      let error = await action.run()
      runningActionTitle = nil
      if let error {
        actionError = error
      } else {
        dismiss()
      }
    }
  }
}

/// A button along the bottom of `FullScreenPhotoView`.
struct FullScreenPhotoAction {
  let title: String
  let systemImage: String
  var role = ActionButtonRole.secondary
  let accessibilityID: String
  /// Returns a message to show if it failed; the viewer closes once it succeeds.
  let run: () async -> String?
}
