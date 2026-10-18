// CoreMems/Views/Components/EditorChrome.swift
import SwiftUI

/// The editor's tools, shown along the bottom.
enum EditTool: CaseIterable, Identifiable {
  case trim
  case crop

  var id: Self { self }

  /// The tools shown for the media being edited, in display order.
  static func available(for support: EditSupport) -> [EditTool] {
    allCases.filter { $0 != .trim || support.trim != .unavailable }
  }

  /// The tool the editor opens on: the first one that can be used.
  static func initial(for support: EditSupport) -> EditTool {
    available(for: support).first { $0.disabledNotice(for: support) == nil } ?? .crop
  }

  /// Why a shown tool can't be used, or `nil` when it can.
  func disabledNotice(for support: EditSupport) -> String? {
    self == .trim && support.trim == .unsupported ? "Slo-mo videos can't be trimmed" : nil
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
  let support: EditSupport
  let playback: VideoPlayback
  let onDone: () -> Void

  private static let noticeHold: Duration = .seconds(2)

  /// Explains why the tool just tapped can't be used.
  @State private var notice: String?

  private var tools: [EditTool] { EditTool.available(for: support) }

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

      if tool == .trim, let duration = support.trim.duration {
        VideoTrimBar(
          range: trimBinding(duration: duration), duration: duration, playback: playback)
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
      }

      if let notice {
        Text(notice)
          .font(.footnote.weight(.medium))
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .frostedGlass(in: Capsule())
          .padding(.bottom, 12)
          .transition(.opacity)
      }

      toolPicker
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .animation(.easeOut(duration: 0.15), value: notice)
    .task(id: notice) {
      guard notice != nil else { return }
      try? await Task.sleep(for: Self.noticeHold)
      notice = nil
    }
  }

  /// A capsule of tools; the selected one is bright with a yellow marker above it.
  private var toolPicker: some View {
    HStack(spacing: 24) {
      ForEach(tools) { tool in
        let isSelected = tool == self.tool
        let disabledNotice = tool.disabledNotice(for: support)
        Button {
          if let disabledNotice {
            notice = disabledNotice
          } else {
            self.tool = tool
          }
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tool.symbol).font(.title2)
            Text(tool.title).font(.caption.weight(.medium))
          }
          .foregroundStyle(
            isSelected ? Color.white : Color.white.opacity(disabledNotice == nil ? 0.5 : 0.25)
          )
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
        .accessibilityHint(disabledNotice ?? "")
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .frostedGlass(in: Capsule())
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
        .frostedGlass(in: Capsule())
    case .crop:
      HStack {
        Button {
          draftEdit?.rotate()
        } label: {
          Image(systemName: "rotate.left")
        }
        .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
        .frostedGlass(in: Circle())
        .accessibilityLabel("Rotate")
        .accessibilityIdentifier(AccessibilityID.editRotate)
        Spacer()
        aspectControl
      }
    }
  }

  /// The aspect ratios a photo can be cropped to, or a button that explains why it can't be.
  @ViewBuilder
  private var aspectControl: some View {
    let icon = Image(systemName: "aspectratio")
    if let sourceSize = support.stillSize {
      Menu {
        Picker("Aspect ratio", selection: aspectBinding(sourceSize: sourceSize)) {
          ForEach(CropAspect.allCases) { Text($0.title) }
        }
      } label: {
        icon
      }
      .menuStyle(.button)
      .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
      .frostedGlass(in: Circle())
      .accessibilityLabel("Aspect ratio")
    } else {
      Button {
        notice = support.cropNotice
      } label: {
        icon
      }
      .buttonStyle(IconButtonStyle(size: .medium, surface: .bare(.white)))
      .opacity(0.5)
      .frostedGlass(in: Circle())
      .accessibilityLabel("Aspect ratio")
      .accessibilityHint(support.cropNotice ?? "")
    }
  }

  /// The draft's trim, shown as the whole video when untrimmed.
  private func trimBinding(duration: Double) -> Binding<ClosedRange<Double>> {
    Binding(
      get: { draftEdit?.trimRange ?? 0...duration },
      set: { draftEdit?.trim(to: $0, ofDuration: duration) })
  }

  private func aspectBinding(sourceSize: CGSize) -> Binding<CropAspect> {
    Binding(
      get: { draftEdit.flatMap { CropAspect.matching($0, sourceSize: sourceSize) } ?? .original },
      set: { draftEdit?.crop(to: $0, ofSourceSize: sourceSize) })
  }

  private var deletesOriginalBinding: Binding<Bool> {
    Binding(
      get: { draftEdit?.deletesOriginal ?? true },
      set: { draftEdit?.deletesOriginal = $0 })
  }
}
