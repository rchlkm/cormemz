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

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero
  @State private var dismissDrag: CGSize = .zero

  private let dismissThreshold: CGFloat = 120
  private let fadeDistance: CGFloat = 400
  private let maxScale: CGFloat = 5.0
  private let doubleTapZoom: CGFloat = 2.5

  private var isZoomed: Bool { scale > 1.01 }

  var body: some View {
    let dismissDistance = hypot(dismissDrag.width, dismissDrag.height)
    let backgroundOpacity = isZoomed ? 1 : max(0, 1 - dismissDistance / fadeDistance)

    ZStack {
      Color.black
        .opacity(backgroundOpacity)
        .ignoresSafeArea()

      AdaptiveAssetImage(
        photo: photo, targetSize: UIScreen.main.bounds.size.turned(by: photo.previewQuarterTurns),
        contentMode: .fit
      )
      .rotated(quarterTurns: photo.previewQuarterTurns)
      .scaleEffect(scale)
      .offset(x: panOffset.width + dismissDrag.width, y: panOffset.height + dismissDrag.height)
      .gesture(magnification)
      .simultaneousGesture(dragGesture)
      .onTapGesture(count: 2) { toggleZoom() }
    }
    .overlay(alignment: .topTrailing) { closeButton.opacity(chromeOpacity) }
    .overlay(alignment: .bottom) { footer.opacity(chromeOpacity) }
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.photoViewer)
  }

  private var chromeOpacity: Double {
    isZoomed ? 0 : max(0, 1 - hypot(dismissDrag.width, dismissDrag.height) / fadeDistance)
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark")
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .accessibilityLabel("Close")
    .disabled(isZoomed)
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
          .disabled(isZoomed || runningActionTitle != nil)
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

  private var magnification: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        scale = min(max(lastScale * value, 1.0), maxScale)
      }
      .onEnded { _ in
        lastScale = scale
        if scale <= 1.05 {
          resetZoom(animated: true)
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        if isZoomed {
          panOffset = CGSize(
            width: lastPanOffset.width + value.translation.width,
            height: lastPanOffset.height + value.translation.height)
        } else {
          dismissDrag = value.translation
        }
      }
      .onEnded { value in
        if isZoomed {
          lastPanOffset = panOffset
        } else {
          let distance = hypot(value.translation.width, value.translation.height)
          if distance > dismissThreshold {
            dismiss()
          } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
              dismissDrag = .zero
            }
          }
        }
      }
  }

  private func toggleZoom() {
    if isZoomed {
      resetZoom(animated: true)
    } else {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        scale = doubleTapZoom
        lastScale = doubleTapZoom
      }
    }
  }

  private func resetZoom(animated: Bool) {
    let apply = {
      scale = 1.0
      lastScale = 1.0
      panOffset = .zero
      lastPanOffset = .zero
    }
    if animated {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75), apply)
    } else {
      apply()
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
