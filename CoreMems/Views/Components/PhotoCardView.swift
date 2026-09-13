// CoreMems/Views/Components/PhotoCardView.swift
import SwiftUI

/// Draggable photo card. Owns its own gesture handling (swipe to
/// keep/delete/undo, pinch to preview, tap for full screen), its own
/// metadata/full-screen/folder-picker presentation, and its own fixed
/// display size; only session-level state mutations flow through `vm`.
struct PhotoCardView: View {
  static let cardSize = CGSize(width: 272, height: 374)

  let photo: SessionPhoto
  @ObservedObject var vm: SessionViewModel

  @State private var dragOffset: CGSize = .zero
  @State private var zoomScale: CGFloat = 1.0
  @State private var showMetadata = false
  @State private var showFullScreen = false
  @State private var showFolderPicker = false

  var body: some View {
    AdaptiveAssetImage(photo: photo, targetSize: Self.cardSize)
      .scaleEffect(zoomScale)
      .gesture(pinchToZoom)
      .overlay(alignment: .top) { topBar }
      .overlay(alignment: .bottomLeading) {
        if photo.isFavorite { favoriteBadge }
      }
      .overlay(keepDeleteStamps)
      .clipShape(RoundedRectangle(cornerRadius: 26))
      .contentShape(RoundedRectangle(cornerRadius: 26))
      .onTapGesture { showFullScreen = true }
      .gesture(dragGesture)
      .offset(dragOffset)
      .rotationEffect(.degrees(Double(dragOffset.width / 18)))
      .shadow(radius: 16, y: 8)
      .animation(.easeOut(duration: 0.2), value: dragOffset)
      .sheet(isPresented: $showMetadata) {
        PhotoMetadataSheetView(vm: vm)
      }
      .sheet(isPresented: $showFolderPicker) {
        FolderPickerView(
          folders: vm.folders,
          assignedFolderIDs: photo.tagFolderIDs,
          onToggle: { folderID in vm.toggleTag(photoID: photo.id, folderID: folderID) },
          onCreate: { name, emoji in
            vm.createFolder(name: name, emoji: emoji, assignToPhotoID: photo.id)
          }
        )
        .presentationDetents([.medium])
      }
      .fullScreenCover(isPresented: $showFullScreen) {
        FullScreenPhotoView(photo: photo)
      }
  }

  /// Pinch to preview the photo enlarged within the card; releasing
  /// always springs the scale back to normal.
  private var pinchToZoom: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        zoomScale = min(max(value, 1.0), 3.0)
      }
      .onEnded { _ in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
          zoomScale = 1.0
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { dragOffset = $0.translation }
      .onEnded { value in
        let dx = value.translation.width
        let dy = value.translation.height
        if dx > 90 {
          vm.decide(index: vm.currentIndex, decision: .keep)
        } else if dy > 90 && abs(dy) > abs(dx) {
          vm.decide(index: vm.currentIndex, decision: .pendingDelete)
        } else if dx < -90 && abs(dx) > abs(dy) && vm.canUndo {
          vm.quickUndo()
        } else if dy < -90 && abs(dy) > abs(dx) {
          vm.showMetadataSheet(for: photo.id)
          showMetadata = true
        }
        dragOffset = .zero
      }
  }

  private var favoriteBadge: some View {
    Image(systemName: "heart.fill")
      .foregroundStyle(.pink)
      .padding(8)
      .background(.white.opacity(0.9), in: Circle())
      .padding(12)
  }

  /// Date on the left, matching where a person's eyes land first;
  /// details and add-to-album controls mirrored on the right.
  private var topBar: some View {
    ZStack {
      LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
        .frame(height: 60)

      HStack {
        if !photo.dateLabel.isEmpty {
          Text(photo.dateLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
        }
        Spacer()
        HStack(spacing: 14) {
          Button {
            vm.showMetadataSheet(for: photo.id)
            showMetadata = true
          } label: {
            Image(systemName: "info.circle.fill")
              .foregroundStyle(.white.opacity(0.9))
          }
          Button {
            showFolderPicker = true
          } label: {
            Image(systemName: "folder.badge.plus")
              .foregroundStyle(.white.opacity(0.9))
          }
        }
      }
      .padding(.horizontal, 14)
    }
    .frame(height: 60)
  }

  private var keepDeleteStamps: some View {
    let keepOpacity = min(1, max(0, dragOffset.width / 90))
    let delOpacity = min(1, max(0, dragOffset.height / 90))
    let detailsOpacity = min(1, max(0, -dragOffset.height / 90))
    return VStack {
      HStack {
        Text("KEEP")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.green.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .rotationEffect(.degrees(-6))
          .opacity(keepOpacity)
        Spacer()
        Text("DETAILS")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .opacity(detailsOpacity)
      }
      .padding(.top, 50)
      Spacer()
      HStack {
        Spacer()
        Text("DELETE")
          .font(.caption.bold()).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .opacity(delOpacity)
      }
    }
    .padding(14)
  }
}
