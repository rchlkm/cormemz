import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var dragOffset: CGSize = .zero
  @State private var showTray = false
  @State private var showFolderPicker = false

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
        // Warm the cache for the next couple of cards so swiping
        // feels instant instead of popping in — §8 performance NFR.
        let upcoming = vm.photos[vm.currentIndex..<min(vm.currentIndex + 4, vm.photos.count)]
          .filter { $0.previewURL == nil }
          .map(\.assetIdentifier)
        if !upcoming.isEmpty {
          await PhotoImageLoader.shared.prefetch(
            identifiers: upcoming, targetSize: CGSize(width: 544, height: 748))
        }
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
        PhotoCardView(photo: p, dragOffset: $dragOffset)
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
        } else if dx < -90 && abs(dx) > abs(dy) && vm.canUndo {  // 👈 new
          vm.quickUndo()
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

/// Draggable photo card. Purely presentational — gesture handling and
/// commit logic live in `ReviewView` so decisions always flow through
/// the view model's single source of truth.
struct PhotoCardView: View {
  let photo: SessionPhoto
  @Binding var dragOffset: CGSize

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 26)
        .fill(Color(.secondarySystemBackground))

      AdaptiveAssetImage(photo: photo, targetSize: CGSize(width: 272, height: 374))
        .clipShape(RoundedRectangle(cornerRadius: 26))

      if photo.isFavorite {
        VStack {
          HStack {
            Image(systemName: "heart.fill")
              .foregroundStyle(.pink)
              .padding(8)
              .background(.white.opacity(0.9), in: Circle())
            Spacer()
          }
          Spacer()
        }
        .padding(12)
      }

      keepDeleteStamps
    }
    .frame(width: 272, height: 374)
    .offset(dragOffset)
    .rotationEffect(.degrees(Double(dragOffset.width / 18)))
    .shadow(radius: 16, y: 8)
    .animation(.easeOut(duration: 0.2), value: dragOffset)
  }

  private var keepDeleteStamps: some View {
    let keepOpacity = min(1, max(0, dragOffset.width / 90))
    let delOpacity = min(1, max(0, dragOffset.height / 90))
    return VStack {
      HStack {
        Text("KEEP")
          .font(.caption.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.green.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .rotationEffect(.degrees(-6))
          .opacity(keepOpacity)
        Spacer()
      }
      Spacer()
      HStack {
        Spacer()
        Text("DELETE")
          .font(.caption.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
          .opacity(delOpacity)
      }
    }
    .padding(14)
  }
}
