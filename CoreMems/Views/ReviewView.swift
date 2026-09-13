// CoreMems/Views/ReviewView.swift
import SwiftUI

struct ReviewView: View {
  @ObservedObject var vm: SessionViewModel

  @State private var showTray = false

  private var current: SessionPhoto? {
    vm.photos.indices.contains(vm.currentIndex) ? vm.photos[vm.currentIndex] : nil
  }

  var body: some View {
    VStack(spacing: 0) {
      TopBar(
        title: "",
        onBack: { vm.exitToHome() },
        trailing: AnyView(
          DeletionTrayButton(pendingCount: vm.pendingItems.count) { showTray = true }
        )
      )

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

      ReviewControlBar(
        canUndo: vm.canUndo,
        onUndo: { vm.quickUndo() },
        onDelete: { vm.decide(index: vm.currentIndex, decision: .pendingDelete) },
        onKeep: { vm.decide(index: vm.currentIndex, decision: .keep) }
      )
    }
    .sheet(isPresented: $showTray) {
      DeletionTrayView(
        items: vm.pendingItems,
        onRestore: { id in vm.restoreMany(ids: [id]) }
      )
      .presentationDetents([.medium, .large])
    }
  }

  /// Only the top (active) card is ever a real `PhotoCardView` — the
  /// two behind it are plain placeholders, sized to match
  /// `PhotoCardView.cardSize` so the stack doesn't jump when the top
  /// card advances.
  @ViewBuilder
  private func cardStack(for photo: SessionPhoto) -> some View {
    let visible = Array(
      vm.photos[vm.currentIndex..<min(vm.currentIndex + 3, vm.photos.count)].enumerated())
    ZStack {
      ForEach(visible.reversed(), id: \.element.id) { offset, p in
        let depth = offset
        if depth == 0 {
          PhotoCardView(photo: p, vm: vm)
        } else {
          RoundedRectangle(cornerRadius: 26)
            .fill(.thinMaterial)
            .frame(width: PhotoCardView.cardSize.width, height: PhotoCardView.cardSize.height)
            .scaleEffect(1 - CGFloat(depth) * 0.045)
            .offset(y: CGFloat(depth) * 9)
            .rotationEffect(.degrees(depth % 2 == 0 ? -2.5 : 2.5))
        }
      }
    }
  }
}
