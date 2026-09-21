// CoreMems/Views/Screens/ReviewView.swift
import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var showTray = false
  @State private var expandedPhoto: SessionPhoto?
  @State private var showCheckIn = false
  @State private var lastCheckInIndex = -1
  @State private var showAlbumPicker = false
  @AppStorage("cm_albumStripExpanded") private var isAlbumStripExpanded = true
  @Namespace private var heroNamespace

  private static let compactAlbumSheetHeight: CGFloat = 340

  private var current: SessionPhoto? {
    vm.photos.indices.contains(vm.currentIndex) ? vm.photos[vm.currentIndex] : nil
  }

  private func actionRail(for photo: SessionPhoto) -> some View {
    GeometryReader { geo in
      PhotoActionRailView(
        isFavorite: photo.isFavorite,
        containerSize: geo.size,
        albumCount: vm.effectiveAlbums(for: photo.id).count,
        isLoadingAlbumData: vm.libraryAlbums == nil,
        onToggleFavorite: { vm.toggleFavorite(photoID: photo.id) },
        onToggleAlbumStrip: { isAlbumStripExpanded.toggle() }
      )
      .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
    }
  }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        TopBar(
          title: "",
          onBack: { vm.exitToHome() },
          trailing: AnyView(
            HStack(spacing: 12) {
              MarkedPhotosTrayButton(markedCount: vm.markedPhotos.count) { showTray = true }
              Button("Done") { vm.finishEarly() }
                .font(.system(size: 15, weight: .semibold))
            }
          )
        )

        VStack(spacing: 2) {
          Text("\(vm.currentIndex) reviewed")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          if let sessionLabel = vm.sessionLabel {
            Text(sessionLabel)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.bottom, 4)

        VStack(spacing: 0) {
          ZStack {
            if let current {
              GeometryReader { geo in
                let maxSize = CGSize(width: geo.size.width - 16, height: geo.size.height - 8)
                ReviewCardView(
                  photo: current, maxSize: maxSize, vm: vm,
                  namespace: heroNamespace, expandedPhoto: $expandedPhoto
                )
                .frame(width: geo.size.width, height: geo.size.height)
                // Per-photo card state (Live Photo playback, drag, zoom) must not carry over.
                .id(current.id)
              }
            } else {
              ProgressView()
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          if let current, isAlbumStripExpanded {
            AlbumQuickStripView(
              vm: vm, photoID: current.id,
              onMore: { showAlbumPicker = true }
            )
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Overlaid on the card-plus-strip container, so the rail stays put
        // as the strip shows and hides and the card resizes.
        .overlay {
          if let current, expandedPhoto?.id != current.id {
            actionRail(for: current)
          }
        }

        ReviewControlBar(
          canUndo: vm.canUndo,
          onUndo: { vm.quickUndo() },
          onDelete: { vm.decide(index: vm.currentIndex, decision: .pendingDelete) },
          onKeep: { vm.decide(index: vm.currentIndex, decision: .keep) }
        )
      }
      .sheet(isPresented: $showTray) {
        MarkedPhotosTrayView(
          items: vm.markedPhotos,
          onRestore: { id in vm.restoreMany(ids: [id]) }
        )
        .presentationDetents([.medium, .large])
      }
      .sheet(isPresented: $showAlbumPicker) {
        if let current {
          AlbumPickerView(
            albums: vm.quickAccessAlbums + vm.pendingNewAlbums,
            assignedRefs: vm.effectiveAlbums(for: current.id),
            libraryAlbums: vm.libraryAlbums,
            onToggle: { ref in vm.toggleAlbumMembership(photoID: current.id, ref: ref) },
            onCreate: { name in vm.createPendingAlbum(name: name, assignToPhotoID: current.id) }
          )
          .presentationDetents([.height(Self.compactAlbumSheetHeight), .medium])
          .presentationDragIndicator(.visible)
        }
      }

      if let expandedPhoto {
        ExpandedPhotoView(
          photo: expandedPhoto, vm: vm, namespace: heroNamespace, expandedPhoto: $expandedPhoto
        )
        .ignoresSafeArea()
        .zIndex(1)
      }

      if showCheckIn {
        CheckInOverlayView(
          reviewedCount: vm.currentIndex,
          onContinue: { showCheckIn = false },
          onDone: {
            showCheckIn = false
            vm.finishEarly()
          }
        )
        .zIndex(2)
      }
    }
    .task {
      await vm.preloadLibraryAlbums()
    }
    .task(id: current?.id) {
      if let id = current?.id { await vm.loadAlbumMembership(for: id) }
    }
    .onChange(of: vm.currentIndex) { _, newIndex in
      guard
        newIndex > 0,
        newIndex % vm.checkInInterval == 0,
        newIndex < vm.photos.count,
        lastCheckInIndex != newIndex
      else { return }
      lastCheckInIndex = newIndex
      showCheckIn = true
    }
  }
}

private struct CheckInOverlayView: View {
  let reviewedCount: Int
  let onContinue: () -> Void
  let onDone: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.42)
        .ignoresSafeArea()

      VStack(spacing: 14) {
        Text("👀")
          .font(.system(size: 30))
        Text("\(reviewedCount) photos reviewed")
          .font(.system(size: 18, weight: .bold))
        Text("Keep going, or call it here for now — your decisions are already saved.")
          .font(.system(size: 13.5))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button("Keep going", action: onContinue)
          .buttonStyle(ActionButtonStyle(role: .primary))

        Button("I'm done for now", action: onDone)
          .buttonStyle(ActionButtonStyle(role: .secondary))
      }
      .padding(24)
      .frame(maxWidth: 300)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
      .shadow(radius: 24)
    }
  }
}
