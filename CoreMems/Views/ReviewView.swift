// CoreMems/Views/ReviewView.swift
import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var dragOffset: CGSize = .zero
  @State private var showTray = false
  @State private var showFolderPicker = false
  @State private var showMetadata = false

  private var current: SessionPhoto? {
    vm.photos.indices.contains(vm.currentIndex) ? vm.photos[vm.currentIndex] : nil
  }

  var body: some View {
    VStack(spacing: 0) {
      TopBar(
        title: "",
        onBack: { vm.exitToHome() },
        trailing: AnyView(trayButton)
      )
      .task(id: vm.currentIndex) {
        // Loads only the single next photo ahead of time — the
        // currently visible one is already loading via its own card.
        let nextIndex = vm.currentIndex + 1
        guard vm.photos.indices.contains(nextIndex) else { return }
        let next = vm.photos[nextIndex]
        guard next.previewURL == nil else { return }
        await PhotoImageLoader.shared.prefetchNext(
          identifier: next.assetIdentifier, targetSize: CGSize(width: 544, height: 748))
      }

      Text("Photo \(min(vm.currentIndex + 1, vm.photos.count)) of \(vm.photos.count)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
        .padding(.bottom, 4)

      ZStack {
        if let current {
          cardStack(for: current)
        } else {
          Color.clear
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      controlBar
    }
    .sheet(isPresented: $showTray) {
      DeletionTrayView(
        items: vm.pendingItems,
        onRestore: { id in vm.restoreMany(ids: [id]) }
      )
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showFolderPicker) {
      if let current {
        FolderPickerView(
          folders: vm.folders,
          assignedFolderIDs: current.tagFolderIDs,
          onToggle: { folderID in vm.toggleTag(photoID: current.id, folderID: folderID) },
          onCreate: { name, emoji in
            vm.createFolder(name: name, emoji: emoji, assignToPhotoID: current.id)
          }
        )
        .presentationDetents([.medium])
      }
    }
    .sheet(isPresented: $showMetadata) {
      PhotoMetadataSheetView(vm: vm)
    }
  }

  private var trayButton: some View {
    Button {
      showTray = true
    } label: {
      ZStack(alignment: .topTrailing) {
        Image(systemName: "tray.full")
          .frame(width: 34, height: 34)
          .background(.thinMaterial, in: Circle())
          .foregroundStyle(vm.pendingItems.isEmpty ? Color.secondary : Color.blue)

        if !vm.pendingItems.isEmpty {
          Text("\(vm.pendingItems.count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.blue, in: Circle())
            .offset(x: 4, y: -4)
        }
      }
    }
  }

  @ViewBuilder
  private func cardStack(for photo: SessionPhoto) -> some View {
    let visible = Array(
      vm.photos[vm.currentIndex..<min(vm.currentIndex + 3, vm.photos.count)].enumerated())

    ForEach(visible.reversed(), id: \.element.id) { offset, p in
      let depth = offset
      if depth == 0 {
        PhotoCardView(
          photo: p,
          dragOffset: $dragOffset,
          onShowDetails: {
            vm.showMetadataSheet(for: p.id)
            showMetadata = true
          }
        )
        .gesture(dragGesture(for: photo))
      } else {
        RoundedRectangle(cornerRadius: 26)
          .fill(.thinMaterial)
          .frame(width: 272, height: 374)
          .scaleEffect(1 - CGFloat(depth) * 0.045)
          .offset(y: CGFloat(depth) * 9)
          .rotationEffect(.degrees(depth % 2 == 0 ? -2.5 : 2.5))
      }
    }
  }

  private func dragGesture(for photo: SessionPhoto) -> some Gesture {
    DragGesture()
      .onChanged { value in dragOffset = value.translation }
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

  private var controlBar: some View {
    VStack(spacing: 12) {
      HStack(spacing: 22) {
        circleButton(
          system: "arrow.uturn.backward", tint: .secondary, size: 48, disabled: !vm.canUndo
        ) {
          vm.quickUndo()
        }
        circleButton(system: "trash", tint: .red, size: 64) {
          vm.decide(index: vm.currentIndex, decision: .pendingDelete)
        }
        circleButton(system: "checkmark", tint: .green, size: 64) {
          vm.decide(index: vm.currentIndex, decision: .keep)
        }
      }

      Button {
        showFolderPicker = true
      } label: {
        Label("Add to folder", systemImage: "tag")
          .font(.footnote.weight(.semibold))
      }
      .buttonStyle(.bordered)
    }
    .padding(.vertical, 18)
    .padding(.bottom, 12)
  }

  private func circleButton(
    system: String, tint: Color, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: size * 0.34, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background(tint.opacity(0.16), in: Circle())
    }
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
  }
}
