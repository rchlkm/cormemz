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

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero
  @State private var dismissDrag: CGSize = .zero
  @State private var inlineLivePhoto: PHLivePhoto?
  @State private var isShowingLivePhoto = false
  /// The edit being made in edit mode; `nil` outside it.
  @State private var draftEdit: MediaEdit?
  @State private var editTool = EditTool.rotate
  @State private var showsSavedStamp = false
  /// Held without observing it, so only the views showing playback redraw as it plays.
  @State private var playback = VideoPlayback()

  private let dismissThreshold: CGFloat = 120
  private let fadeDistance: CGFloat = 400
  private let maxScale: CGFloat = 5.0
  private let doubleTapZoom: CGFloat = 2.5
  private let savedStampHold: Duration = .milliseconds(450)
  /// Room kept clear for the editor's bars, so they sit on black rather than on the photo.
  private let baseEditorInsets = EdgeInsets(top: 150, leading: 16, bottom: 60, trailing: 16)
  /// Extra room below the photo for the trim bar, which sits above the tool picker.
  private let trimBarExtraHeight: CGFloat = 88

  private var isZoomed: Bool { scale > 1.01 }
  private var isEditing: Bool { draftEdit != nil }
  private var quarterTurns: Int { draftEdit?.quarterTurns ?? photo.previewQuarterTurns }
  private var trimRange: ClosedRange<Double>? {
    isEditing ? draftEdit?.trimRange : photo.activeEdit?.trimRange
  }
  private var trimDuration: Double? { vm.trimmableDuration(of: photo) }
  /// In the Trim tool, the trim bar stands in for the player's own transport bar.
  private var showsTrimBar: Bool { isEditing && editTool == .trim && trimDuration != nil }
  private var availableTools: [EditTool] {
    EditTool.allCases.filter { $0 != .trim || trimDuration != nil }
  }
  private var savedEdit: MediaEdit { photo.activeEdit ?? MediaEdit() }
  /// Viewing gestures are off in edit mode.
  private var viewingGestures: GestureMask { isEditing ? .subviews : .all }

  /// Kept the same for every tool, so switching tools doesn't move the photo.
  private var editorInsets: EdgeInsets {
    var insets = baseEditorInsets
    if availableTools.contains(.trim) { insets.bottom += trimBarExtraHeight }
    return insets
  }

  /// The space the photo fits in: the whole screen, or between the bars in edit mode.
  private var contentBox: CGSize {
    let screen = UIScreen.main.bounds.size
    guard isEditing else { return screen }
    return CGSize(
      width: screen.width - editorInsets.leading - editorInsets.trailing,
      height: screen.height - editorInsets.top - editorInsets.bottom)
  }

  var body: some View {
    let dismissDistance = hypot(dismissDrag.width, dismissDrag.height)
    let backgroundOpacity = isZoomed ? 1 : max(0, 1 - dismissDistance / fadeDistance)

    ZStack {
      Color.black
        .opacity(backgroundOpacity)
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
        .scaleEffect(scale)
        .offset(x: panOffset.width + dismissDrag.width, y: panOffset.height + dismissDrag.height)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: quarterTurns)
        .gesture(magnification, including: viewingGestures)
        .simultaneousGesture(dragGesture, including: viewingGestures)
        .gesture(TapGesture(count: 2).onEnded { toggleZoom() }, including: viewingGestures)

      if photo.isLivePhoto && !isEditing {
        VStack {
          HStack {
            LivePhotoBadgeView(
              assetIdentifier: photo.assetIdentifier,
              targetSize: UIScreen.main.bounds.size,
              inlineLivePhoto: $inlineLivePhoto,
              isShowingLivePhoto: $isShowingLivePhoto,
              canConvertToStill: vm.canConvertToStill(photo),
              onConvertToStill: convertToStill,
              style: .pill
            )
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
    .overlay(alignment: .topTrailing) {
      if !isEditing && !isZoomed { editButton }
    }
    .overlay {
      if isEditing && !showsSavedStamp { editorChrome }
    }
    .animation(.easeOut(duration: 0.15), value: vm.markingDecision)
    .animation(.easeOut(duration: 0.15), value: showsSavedStamp)
    .statusBarHidden()
    .uiTestContainer(AccessibilityID.expandedPhoto)
  }

  @ViewBuilder
  private var content: some View {
    if isShowingLivePhoto, let inlineLivePhoto {
      LivePhotoPlayerView(
        livePhoto: inlineLivePhoto, onPlaybackEnded: { isShowingLivePhoto = false }
      )
      .rotated(quarterTurns: quarterTurns)
    } else if photo.isVideo {
      VideoPlayerCardView(
        playback: playback, assetIdentifier: photo.assetIdentifier, quarterTurns: quarterTurns,
        playbackRange: trimRange, showsTransport: !showsTrimBar)
    } else {
      AdaptiveAssetImage(
        photo: photo, fitWithin: contentBox.turned(by: quarterTurns)
      )
      .rotated(quarterTurns: quarterTurns)
    }
  }

  private var editButton: some View {
    Button {
      resetZoom(animated: true)
      isShowingLivePhoto = false
      editTool = availableTools[0]
      draftEdit = photo.edit ?? MediaEdit()
    } label: {
      Image(systemName: EditStyle.symbol)
    }
    .buttonStyle(IconButtonStyle(size: .small, surface: .scrim))
    .accessibilityLabel("Edit")
    .accessibilityIdentifier(AccessibilityID.editStart)
    .padding(.trailing, 20)
    .padding(.top, 50)
  }

  /// Cancel and Done along the top, the current tool's controls under them, and the tools
  /// along the bottom with the trim bar above them, as in the Photos editor.
  private var editorChrome: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Cancel") { draftEdit = nil }
          .accessibilityIdentifier(AccessibilityID.editCancel)
        Spacer()
        Button("Done", action: finishEditing)
          .fontWeight(.semibold)
          .foregroundStyle(.yellow)
          .disabled(draftEdit == nil || draftEdit == savedEdit)
          .accessibilityIdentifier(AccessibilityID.editDone)
      }
      .padding(.horizontal, 20)
      .padding(.top, 50)

      toolControls
        .padding(.horizontal, 12)
        .padding(.top, 8)

      Spacer()

      if showsTrimBar, let trimDuration {
        VideoTrimBar(
          range: trimBinding(duration: trimDuration), duration: trimDuration, playback: playback)
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
      }

      // A single tool needs no picker; its controls are already showing.
      if availableTools.count > 1 {
        toolPicker
      }
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
  }

  private var toolPicker: some View {
    HStack(spacing: 28) {
      ForEach(availableTools) { tool in
        Button {
          editTool = tool
        } label: {
          Label(tool.title, systemImage: tool.symbol)
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(tool == editTool ? Color.yellow : Color.white)
        }
        .accessibilityLabel(tool.title)
      }
    }
    .padding(.bottom, 40)
  }

  @ViewBuilder
  private var toolControls: some View {
    switch editTool {
    case .trim:
      Toggle("Delete original", isOn: deletesOriginalBinding)
        .tint(.yellow)
        .disabled(draftEdit?.trimRange == nil)
    case .rotate:
      HStack {
        Button {
          draftEdit?.rotate()
        } label: {
          Image(systemName: "rotate.left")
        }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
        .accessibilityLabel("Rotate")
        .accessibilityIdentifier(AccessibilityID.editRotate)
        Spacer()
      }
    }
  }

  /// The draft's trim, shown as the whole video when untrimmed.
  private func trimBinding(duration: Double) -> Binding<ClosedRange<Double>> {
    Binding(
      get: { draftEdit?.trimRange ?? 0...duration },
      set: { draftEdit?.trim(to: $0, ofDuration: duration) })
  }

  private var deletesOriginalBinding: Binding<Bool> {
    Binding(
      get: { draftEdit?.deletesOriginal ?? true },
      set: { draftEdit?.deletesOriginal = $0 })
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
            close()
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

/// The editor's tools, shown along the bottom.
private enum EditTool: CaseIterable, Identifiable {
  case trim
  case rotate

  var id: Self { self }

  var title: String {
    switch self {
    case .trim: return "Trim"
    case .rotate: return "Rotate"
    }
  }

  var symbol: String {
    switch self {
    case .trim: return "timeline.selection"
    case .rotate: return "crop.rotate"
    }
  }
}
