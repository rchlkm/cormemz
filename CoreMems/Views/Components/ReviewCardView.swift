// CoreMems/Views/Components/ReviewCardView.swift
import PhotosUI
import SwiftUI

/// Interactive review card: swipe-to-decide gestures, pinch zoom, and
/// all card chrome (date, add-to-album, favorite/Live Photo badges).
/// `PhotoCardView` underneath only renders the photo.
///
/// Expanding to full screen is a `matchedGeometryEffect` hand-off to
/// `ExpandedPhotoView`, not a `.fullScreenCover` — the photo grows into
/// full screen instead of a modal sliding up.
struct ReviewCardView: View {
  let photo: SessionPhoto
  let maxSize: CGSize
  @ObservedObject var vm: SessionViewModel
  var namespace: Namespace.ID
  @Binding var expandedPhoto: SessionPhoto?

  @State private var dragOffset: CGSize = .zero
  @State private var zoomScale: CGFloat = 1.0
  @State private var showMetadata = false
  @State private var showFolderPicker = false
  @State private var inlineLivePhoto: PHLivePhoto?
  @State private var isShowingLivePhoto = false

  /// Pinch scale past which the card hands off to full screen instead
  /// of bouncing back.
  private let fullScreenZoomThreshold: CGFloat = 1.6

  private var isExpanded: Bool { expandedPhoto?.id == photo.id }

  var body: some View {
    // ExpandedPhotoView shares this card's matchedGeometryEffect id,
    // so while expanded this spot renders nothing and the photo
    // appears to grow out of it instead.
    Group {
      if !isExpanded {
        cardContent
      }
    }
  }

  private var cardContent: some View {
    Group {
      if isShowingLivePhoto, let inlineLivePhoto {
        LivePhotoPlayerView(livePhoto: inlineLivePhoto)
          .aspectRatio(inlineLivePhoto.size, contentMode: .fit)
          .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
      } else {
        PhotoCardView(photo: photo, maxSize: maxSize)
          .matchedGeometryEffect(id: photo.id, in: namespace)
      }
    }
    .scaleEffect(zoomScale)
    .gesture(pinchToZoom)
    .overlay(alignment: .top) { topBar }
    .overlay(alignment: .bottomLeading) {
      if photo.isLivePhoto { livePhotoBadge }
    }
    .overlay(alignment: .bottomTrailing) {
      infoBadge
    }
    .overlay(keepDeleteStamps)
    .clipShape(RoundedRectangle(cornerRadius: 26))
    .contentShape(RoundedRectangle(cornerRadius: 26))
    .onTapGesture { expand() }
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
  }

  private func expand() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      expandedPhoto = photo
    }
  }

  /// Crossing `fullScreenZoomThreshold` mid-gesture hands off to
  /// `expand()` immediately, so the card keeps growing continuously
  /// into full screen instead of bouncing back and popping open.
  private var pinchToZoom: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        if value > fullScreenZoomThreshold {
          zoomScale = 1.0
          expand()
        } else {
          zoomScale = value
        }
      }
      .onEnded { value in
        guard value <= fullScreenZoomThreshold else { return }
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

  /// Tapping plays the Live Photo in place of the static image;
  /// tapping again while playing reverts to it.
  private var livePhotoBadge: some View {
    Button {
      if isShowingLivePhoto {
        isShowingLivePhoto = false
      } else {
        let targetSize = CGSize(width: maxSize.width * 2, height: maxSize.height * 2)
        Task {
          inlineLivePhoto = await LivePhotoLoader.shared.livePhoto(
            for: photo.assetIdentifier, targetSize: targetSize)
          isShowingLivePhoto = inlineLivePhoto != nil
        }
      }
    } label: {
      Image(systemName: isShowingLivePhoto ? "livephoto.slash" : "livephoto")
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.55), in: Circle())
    }
    .padding(12)
  }

  private var infoBadge: some View {
    Button {
      vm.showMetadataSheet(for: photo.id)
      showMetadata = true
    } label: {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.55), in: Circle())
    }
    .padding(12)
  }

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
        if photo.isFavorite {
          Image(systemName: "heart.fill")
            .foregroundStyle(.pink)
        }
        Button {
          showFolderPicker = true
        } label: {
          Image(systemName: "folder.badge.plus")
            .foregroundStyle(.white.opacity(0.9))
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