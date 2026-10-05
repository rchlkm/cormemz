// CoreMems/Views/Components/ExpandedPhotoView.swift
import PhotosUI
import SwiftUI

/// Full-screen state of a `BrowseCardView` photo, grown into place via
/// `matchedGeometryEffect` rather than a `.fullScreenCover` modal.
/// Pinch to zoom (persists, no bounce-back), drag to pan while zoomed,
/// or drag at 1x to shrink back down into the card. Live Photos can be
/// played here too, in place of the static image. Edit mode stages an
/// edit on the photo without deciding it, laid out like the Photos editor.
struct ExpandedPhotoView: View {
  let photo: SessionPhoto
  @ObservedObject var vm: SessionViewModel
  var namespace: Namespace.ID
  @Binding var expandedPhoto: SessionPhoto?

  @State private var zoom = ZoomPanState()
  @State private var inlineLivePhoto: PHLivePhoto?
  @State private var isShowingLivePhoto = false
  @StateObject private var frameState = LivePhotoFrameState()
  /// The edit being made in edit mode; `nil` outside it.
  @State private var draftEdit: MediaEdit?
  @State private var editTool = EditTool.crop
  @State private var showsSavedStamp = false
  /// Held without observing it, so only the views showing playback redraw as it plays.
  @State private var playback = VideoPlayback()

  private let savedStampHold: Duration = .milliseconds(450)
  /// Room kept clear for the editor's bars, including the video trim bar above the tool
  /// picker, so they sit on black rather than on the photo and the photo sits the same for
  /// every kind of media.
  private let editorInsets = EdgeInsets(top: 150, leading: 16, bottom: 148, trailing: 16)

  private var isEditing: Bool { draftEdit != nil }
  private var quarterTurns: Int { draftEdit?.quarterTurns ?? photo.previewQuarterTurns }
  private var trim: TrimSupport { vm.trimSupport(of: photo) }
  /// In the Trim tool, the trim bar stands in for the player's own transport bar.
  private var showsTrimBar: Bool { isEditing && editTool == .trim && trim.duration != nil }
  private var savedEdit: MediaEdit { photo.activeEdit ?? MediaEdit() }
  /// Viewing gestures are off in edit mode.
  private var viewingGestures: GestureMask { isEditing ? .subviews : .all }

  /// The space the photo fits in: the whole screen, or between the bars in edit mode.
  private var contentBox: CGSize {
    let screen = UIScreen.main.bounds.size
    guard isEditing else { return screen }
    return CGSize(
      width: screen.width - editorInsets.leading - editorInsets.trailing,
      height: screen.height - editorInsets.top - editorInsets.bottom)
  }

  var body: some View {
    ZStack {
      Color.black
        .opacity(zoom.backgroundOpacity)
        .ignoresSafeArea()

      content
        .padding(isEditing ? editorInsets : EdgeInsets())
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditing)
        .livePhotoLongPress(
          isEnabled: photo.isLivePhoto && !isEditing,
          assetIdentifier: photo.assetIdentifier,
          targetSize: UIScreen.main.bounds.size,
          inlineLivePhoto: $inlineLivePhoto,
          isShowingLivePhoto: $isShowingLivePhoto
        )
        .matchedGeometryEffect(id: photo.id, in: namespace)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: quarterTurns)
        .zoomPanDismiss($zoom, gestures: viewingGestures, onDismiss: close)

      if (photo.isLivePhoto || photo.kind != nil) && !isEditing {
        VStack {
          HStack {
            mediaBadge
            Spacer()
          }
          Spacer()
        }
        .padding(.leading, 20)
        .padding(.top, 50)
      }

      if let decision = vm.markingDecision {
        DecisionOverlay(decision: decision).transition(.opacity)
      } else if showsSavedStamp {
        DecisionOverlay.edited.transition(.opacity)
      }
    }
    .overlay(alignment: .bottom) {
      if !isEditing { viewingControls }
    }
    .task(id: isEditing) { if !isEditing { await frameState.open(for: photo) } }
    .task(id: frameState.time) { await frameState.loadImage() }
    .overlay {
      if isEditing && !showsSavedStamp {
        EditorChrome(
          draftEdit: $draftEdit, tool: $editTool, savedEdit: savedEdit,
          trim: trim, playback: playback, onDone: finishEditing)
      }
    }
    .animation(.easeOut(duration: 0.15), value: vm.markingDecision)
    .animation(.easeOut(duration: 0.15), value: showsSavedStamp)
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.expandedPhoto)
  }

  private var content: some View {
    PhotoCardView(
      photo: photo, maxSize: contentBox, playback: playback, draftEdit: draftEdit,
      showsTransport: !showsTrimBar,
      livePhoto: isShowingLivePhoto ? inlineLivePhoto : nil,
      onLivePhotoEnded: { isShowingLivePhoto = false }, still: frameState.image)
  }

  @ViewBuilder private var mediaBadge: some View {
    if photo.isLivePhoto {
      LivePhotoBadgeView(
        assetIdentifier: photo.assetIdentifier,
        targetSize: UIScreen.main.bounds.size,
        inlineLivePhoto: $inlineLivePhoto,
        isShowingLivePhoto: $isShowingLivePhoto,
        canConvertToStill: vm.canConvertToStill(photo),
        onConvertToStill: convertToStill,
        style: .pill
      )
    } else if let kind = photo.kind {
      MediaKindBadge(kind: kind)
    }
  }

  /// The Live Photo's frame scrubber, when open, above the Edit button.
  private var viewingControls: some View {
    VStack(spacing: 20) {
      if let frames = frameState.frames, frameState.time != nil {
        frameScrubber(frames).padding(.horizontal, 16)
      }
      if !zoom.isZoomed { editButton }
    }
    .padding(.bottom, 40)
  }

  private func frameScrubber(_ frames: LivePhotoFrames) -> some View {
    LivePhotoFrameScrubber(
      frames: frames,
      time: Binding(
        get: { frameState.time ?? frames.keyPhotoTime }, set: { frameState.time = $0 })
    )
  }

  private var editButton: some View {
    Button {
      resetZoom(animated: true)
      isShowingLivePhoto = false
      frameState.close()
      editTool = EditTool.initial(for: trim)
      draftEdit = photo.edit ?? MediaEdit()
    } label: {
      Image(systemName: EditStyle.symbol)
    }
    .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
    .frostedGlass(in: Circle())
    .accessibilityLabel("Edit")
    .accessibilityIdentifier(AccessibilityID.editStart)
  }

  /// Stages the draft, or discards the photo's edit when the draft undoes it, then shows the
  /// stamp and returns to the card.
  private func finishEditing() {
    guard let draftEdit else { return }
    if draftEdit.isEmpty {
      vm.restoreMany(ids: [photo.id])
    } else if !vm.saveEdit(draftEdit, photoID: photo.id) {
      return
    }
    showsSavedStamp = true
    Task {
      try? await Task.sleep(for: savedStampHold)
      close()
    }
  }

  private func resetZoom(animated: Bool) {
    if animated {
      withAnimation(ZoomPanState.zoomAnimation) { zoom.reset() }
    } else {
      zoom.reset()
    }
  }

  /// Deciding moves the deck on, so full screen closes once the mark has shown.
  private func convertToStill() {
    guard let recording = vm.decide(photoID: photo.id, decision: .convertToStill) else {
      return
    }
    Task {
      await recording.value
      close()
    }
  }

  /// Mirrors the expand transition, shrinking back into the card that
  /// grew from the same `matchedGeometryEffect` id.
  private func close() {
    resetZoom(animated: false)
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      expandedPhoto = nil
    }
  }
}
