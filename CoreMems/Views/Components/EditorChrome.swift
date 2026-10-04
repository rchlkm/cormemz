// CoreMems/Views/Components/EditorChrome.swift
import SwiftUI

/// The editor's tools, shown along the bottom.
enum EditTool: CaseIterable, Identifiable {
  case trim
  case crop

  var id: Self { self }

  /// The tools that apply to the media being edited, in display order.
  static func available(canTrim: Bool) -> [EditTool] {
    allCases.filter { $0 != .trim || canTrim }
  }

  var title: String {
    switch self {
    case .trim: return "Trim"
    case .crop: return "Crop"
    }
  }

  var symbol: String {
    switch self {
    case .trim: return "timeline.selection"
    case .crop: return "crop.rotate"
    }
  }
}

/// Cancel and Done along the top, the current tool's controls under them, and the tools
/// along the bottom with the trim bar above them, as in the Photos editor.
struct EditorChrome: View {
  @Binding var draftEdit: MediaEdit?
  @Binding var tool: EditTool
  let savedEdit: MediaEdit
  /// Length of the video being edited; `nil` when the media can't be trimmed.
  let trimDuration: Double?
  let playback: VideoPlayback
  let onDone: () -> Void

  private var tools: [EditTool] { EditTool.available(canTrim: trimDuration != nil) }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Cancel") { draftEdit = nil }
          .editorPill()
          .accessibilityIdentifier(AccessibilityID.editCancel)
        Spacer()
        Button("Done", action: onDone)
          .editorPill(tint: .yellow)
          .disabled(draftEdit == nil || draftEdit == savedEdit)
          .accessibilityIdentifier(AccessibilityID.editDone)
      }
      .padding(.horizontal, 20)
      .padding(.top, 50)

      toolControls
        .padding(.horizontal, 12)
        .padding(.top, 8)

      Spacer()

      if tool == .trim, let trimDuration {
        VideoTrimBar(
          range: trimBinding(duration: trimDuration), duration: trimDuration, playback: playback)
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
      }

      toolPicker
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
  }

  /// A capsule of tools; the selected one is bright with a yellow marker above it.
  private var toolPicker: some View {
    HStack(spacing: 24) {
      ForEach(tools) { tool in
        let isSelected = tool == self.tool
        Button {
          self.tool = tool
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tool.symbol).font(.title2)
            Text(tool.title).font(.caption.weight(.medium))
          }
          .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
          .frame(minWidth: 56)
          .overlay(alignment: .top) {
            if isSelected {
              Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7))
                .foregroundStyle(.yellow)
                .offset(y: -10)
            }
          }
        }
        .accessibilityLabel(tool.title)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .editorGlass(in: Capsule())
    .padding(.bottom, 40)
  }

  @ViewBuilder
  private var toolControls: some View {
    switch tool {
    case .trim:
      Toggle("Delete original", isOn: deletesOriginalBinding)
        .tint(.yellow)
        .disabled(draftEdit?.trimRange == nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .editorGlass(in: Capsule())
    case .crop:
      HStack {
        HStack(spacing: 0) {
          Button {} label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
            .disabled(true)
            .accessibilityLabel("Flip")
          Button {
            draftEdit?.rotate()
          } label: {
            Image(systemName: "rotate.left")
          }
          .accessibilityLabel("Rotate")
          .accessibilityIdentifier(AccessibilityID.editRotate)
        }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
        .editorGlass(in: Capsule())
        Spacer()
        Button {} label: { Image(systemName: "aspectratio") }
          .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
          .editorGlass(in: Capsule())
          .disabled(true)
          .accessibilityLabel("Aspect ratio")
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
}
